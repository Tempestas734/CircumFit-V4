"""Segmentation de la silhouette pour la mesure du tour de taille (A-04, F-23).

Principe
--------
La V2 cherchait le bord de la silhouette avec Canny en partant du centre de
l'image : la mesure s'arrêtait sur le premier bord rencontré (motif d'un
vêtement, ombre, bras, objet du décor).

La V3 utilise en priorité le **masque de segmentation** fourni par le modèle
MediaPipe Pose déjà embarqué sur le serveur (``enable_segmentation=True``) :
chaque pixel reçoit une probabilité d'appartenir à la personne. Sur la ligne
de mesure, la largeur est celle du segment de pixels « personne » qui contient
le centre du tronc.

Canny reste en **repli** si le masque est absent ou jugé inexploitable
(contrôles ci-dessous). La méthode utilisée et la raison d'un éventuel repli
sont toujours renvoyées, pour la traçabilité et la campagne de validation.

F-23 : la largeur est mesurée sur plusieurs lignes autour du niveau retenu
et la médiane des lignes valides est gardée (``mesurer_multilignes``), pour
limiter l'effet d'un bord mal détecté sur une ligne.

Toutes les fonctions de ce module sont pures (pas de lecture de fichier, pas
d'appel au modèle) afin d'être testables sans MediaPipe (voir A-07).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

import cv2
import numpy as np

# Probabilité au-dessus de laquelle un pixel est considéré comme « personne ».
SEUIL_MASQUE = 0.5

# Part minimale / maximale de l'image que doit occuper la silhouette pour que
# le masque soit jugé plausible (sujet en pied, photo cadrée selon le protocole).
FRACTION_MASQUE_MIN = 0.01
FRACTION_MASQUE_MAX = 0.90

# Largeur plausible du segment mesuré, en fraction de la largeur de l'image.
FRACTION_SEGMENT_MIN = 0.02
FRACTION_SEGMENT_MAX = 0.90

# Seuils de Canny conservés de la V2 pour le repli.
SEUILS_CANNY = (50, 150)

METHODE_MASQUE = "masque"
METHODE_CANNY = "canny"
METHODE_MIXTE = "mixte"  # F-23 : lignes mesurées par le masque et par Canny

# Mesure multi-lignes (F-23) : nombre de lignes et demi-hauteur de la bande,
# en fraction de la hauteur du sujet en pixels (indépendant de la résolution).
# Valeurs proposées sans calibration, à revoir avec la campagne E-06.
N_LIGNES = 9
DEMI_BANDE_FRACTION = 0.02
# Part minimale de lignes valides pour accepter la médiane.
FRACTION_LIGNES_VALIDES_MIN = 0.5

Segment = Tuple[int, int]


@dataclass(frozen=True)
class ResultatSegment:
    """Résultat de la recherche des bords de la silhouette sur une ligne."""

    x_gauche: int
    x_droite: int
    methode: str  # "masque" ou "canny"
    raison_repli: Optional[str] = None  # pourquoi le masque n'a pas été retenu

    @property
    def largeur_px(self) -> int:
        """Largeur complète en pixels (bord gauche inclus, bord droit exclu)."""
        return self.x_droite - self.x_gauche


# ---------------------------------------------------------------------------
# Masque
# ---------------------------------------------------------------------------

def binariser_masque(masque_proba: np.ndarray, seuil: float = SEUIL_MASQUE) -> np.ndarray:
    """Convertit le masque de probabilités (0..1) en masque binaire uint8 (0/1)."""
    masque_proba = np.asarray(masque_proba, dtype=np.float32)
    if masque_proba.ndim == 3:
        masque_proba = masque_proba[..., 0]
    return (masque_proba > seuil).astype(np.uint8)


def nettoyer_masque(masque_bin: np.ndarray, ancrage: Tuple[int, int]) -> np.ndarray:
    """Lisse le masque et ne garde que la composante connexe de la personne.

    - fermeture puis ouverture morphologiques (noyau ≈ 1 % de la hauteur) pour
      boucher les petits trous et supprimer les grains isolés ;
    - conservation de la seule composante connexe qui contient le point
      d'ancrage (centre des hanches), ou à défaut la plus proche : un objet
      du décor détecté à tort ne peut donc pas être mesuré.

    Args:
        masque_bin: masque binaire (0/1).
        ancrage: (x, y) en pixels, point supposé appartenir au tronc.
    """
    hauteur, largeur = masque_bin.shape[:2]
    k = max(3, int(round(hauteur * 0.01)) | 1)  # taille impaire
    noyau = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k))
    masque = cv2.morphologyEx(masque_bin.astype(np.uint8), cv2.MORPH_CLOSE, noyau)
    masque = cv2.morphologyEx(masque, cv2.MORPH_OPEN, noyau)

    n, etiquettes, stats, _ = cv2.connectedComponentsWithStats(masque, connectivity=8)
    if n <= 1:
        return masque  # aucun pixel « personne »

    x, y = _borner(ancrage, largeur, hauteur)
    etiquette = etiquettes[y, x]
    if etiquette == 0:
        # L'ancrage tombe hors du masque : on prend la composante la plus proche.
        ys, xs = np.nonzero(etiquettes)
        i = int(np.argmin((xs - x) ** 2 + (ys - y) ** 2))
        etiquette = etiquettes[ys[i], xs[i]]
    return (etiquettes == etiquette).astype(np.uint8)


def controler_masque(masque_bin: np.ndarray) -> Optional[str]:
    """Vérifie que le masque est exploitable. Renvoie None si OK, sinon la raison."""
    if masque_bin is None or masque_bin.size == 0:
        return "masque absent"
    fraction = float(masque_bin.mean())
    if fraction < FRACTION_MASQUE_MIN:
        return f"masque quasi vide ({fraction:.1%} de l'image)"
    if fraction > FRACTION_MASQUE_MAX:
        return f"masque couvrant presque toute l'image ({fraction:.1%})"
    return None


def segment_masque(masque_bin: np.ndarray, y: int, x_ref: int,
                   tolerance_px: Optional[int] = None) -> Optional[Segment]:
    """Segment de pixels « personne » de la ligne ``y`` qui contient ``x_ref``.

    Si ``x_ref`` tombe dans un trou du masque, on prend le segment le plus
    proche à moins de ``tolerance_px`` (5 % de la largeur par défaut).

    Returns:
        (x_gauche, x_droite) avec x_droite exclu, ou None.
    """
    hauteur, largeur = masque_bin.shape[:2]
    if not 0 <= y < hauteur:
        return None
    x_ref = int(np.clip(x_ref, 0, largeur - 1))
    ligne = masque_bin[y].astype(bool)
    if not ligne.any():
        return None

    if not ligne[x_ref]:
        if tolerance_px is None:
            tolerance_px = max(1, int(0.05 * largeur))
        xs = np.flatnonzero(ligne)
        x_proche = int(xs[np.argmin(np.abs(xs - x_ref))])
        if abs(x_proche - x_ref) > tolerance_px:
            return None
        x_ref = x_proche

    # Bords du segment contenant x_ref
    gauche = ligne[:x_ref][::-1]
    droite = ligne[x_ref:]
    n_gauche = int(np.argmin(gauche)) if not gauche.all() else gauche.size
    n_droite = int(np.argmin(droite)) if not droite.all() else droite.size
    return x_ref - n_gauche, x_ref + n_droite


# ---------------------------------------------------------------------------
# Canny (repli)
# ---------------------------------------------------------------------------

def segment_canny(image_gris: np.ndarray, y: int, x_ref: int,
                  seuils: Tuple[int, int] = SEUILS_CANNY) -> Optional[Segment]:
    """Méthode V2 : premier bord de Canny de part et d'autre de ``x_ref``.

    Différence avec la V2 : le balayage part du centre du tronc (``x_ref``)
    et non du centre de l'image, et l'absence de bord renvoie None au lieu
    d'une largeur égale à toute l'image.
    """
    hauteur, largeur = image_gris.shape[:2]
    if not 0 <= y < hauteur:
        return None
    x_ref = int(np.clip(x_ref, 0, largeur - 1))
    bords = cv2.Canny(image_gris, *seuils)[y]

    gauche = np.flatnonzero(bords[:x_ref])
    droite = np.flatnonzero(bords[x_ref:])
    if gauche.size == 0 or droite.size == 0:
        return None
    return int(gauche[-1]), int(x_ref + droite[0])


# ---------------------------------------------------------------------------
# Contrôle et choix de la méthode
# ---------------------------------------------------------------------------

def controler_segment(segment: Optional[Segment], largeur_image: int) -> Optional[str]:
    """Vérifie qu'un segment est plausible. Renvoie None si OK, sinon la raison."""
    if segment is None:
        return "aucun bord trouvé sur la ligne de mesure"
    x_g, x_d = segment
    if x_g <= 0 or x_d >= largeur_image:
        return "la silhouette touche le bord de l'image"
    fraction = (x_d - x_g) / largeur_image
    if fraction < FRACTION_SEGMENT_MIN:
        return f"largeur trop faible ({fraction:.1%} de l'image)"
    if fraction > FRACTION_SEGMENT_MAX:
        return f"largeur trop grande ({fraction:.1%} de l'image)"
    return None


def preparer_masque(image_bgr: np.ndarray, masque_proba: Optional[np.ndarray],
                    ancrage: Tuple[int, int],
                    seuil: float = SEUIL_MASQUE) -> Tuple[Optional[np.ndarray], Optional[str]]:
    """Binarise, contrôle et nettoie le masque une seule fois pour toute l'image.

    Returns:
        (masque nettoyé, None) si le masque est exploitable,
        (None, raison) sinon.
    """
    hauteur, largeur = image_bgr.shape[:2]
    if masque_proba is None:
        return None, "masque absent"
    if np.asarray(masque_proba).shape[:2] != (hauteur, largeur):
        return None, "masque de taille différente de l'image"
    masque = binariser_masque(masque_proba, seuil)
    raison = controler_masque(masque)
    if raison is not None:
        return None, raison
    return nettoyer_masque(masque, ancrage), None


class _BordsCanny:
    """Calcule Canny sur toute l'image au premier besoin seulement."""

    def __init__(self, image_bgr: np.ndarray):
        self._image = image_bgr
        self._gris = None

    @property
    def gris(self) -> np.ndarray:
        if self._gris is None:
            self._gris = cv2.cvtColor(self._image, cv2.COLOR_BGR2GRAY)
        return self._gris


def _mesurer_ligne(masque: Optional[np.ndarray], raison_masque: Optional[str],
                   canny: _BordsCanny, y: int, x_ref: int,
                   largeur: int) -> Optional[ResultatSegment]:
    """Bords sur une ligne avec un masque déjà préparé : masque puis Canny."""
    raison = raison_masque
    if masque is not None:
        segment = segment_masque(masque, y, x_ref)
        raison = controler_segment(segment, largeur)
        if raison is None:
            return ResultatSegment(segment[0], segment[1], METHODE_MASQUE)

    segment = segment_canny(canny.gris, y, x_ref)
    if controler_segment(segment, largeur) is None:
        return ResultatSegment(segment[0], segment[1], METHODE_CANNY, raison)
    return None


def mesurer_segment(image_bgr: np.ndarray, masque_proba: Optional[np.ndarray],
                    y: int, x_ref: int,
                    seuil: float = SEUIL_MASQUE) -> Optional[ResultatSegment]:
    """Bords de la silhouette sur la ligne ``y`` : masque d'abord, Canny en repli.

    Args:
        image_bgr: image d'origine (pour Canny).
        masque_proba: masque de segmentation MediaPipe (probabilités 0..1,
            même taille que l'image) ou None.
        y: ordonnée de la ligne de mesure, en pixels.
        x_ref: abscisse d'un point du tronc (milieu des hanches), en pixels.
        seuil: seuil de binarisation du masque.

    Returns:
        ResultatSegment, ou None si aucune des deux méthodes n'aboutit.
    """
    largeur = image_bgr.shape[1]
    masque, raison = preparer_masque(image_bgr, masque_proba, (x_ref, y), seuil)
    return _mesurer_ligne(masque, raison, _BordsCanny(image_bgr), y, x_ref, largeur)


# ---------------------------------------------------------------------------
# Mesure multi-lignes (F-23)
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class ResultatMultiLignes:
    """Médiane des largeurs mesurées sur plusieurs lignes autour du niveau retenu."""

    largeur_px: float                 # médiane des largeurs valides
    segment_median: ResultatSegment   # ligne valide la plus proche de la médiane
    y_median: int                     # ordonnée de cette ligne (affichage)
    n_valides: int
    n_lignes: int
    ecart_px: int                     # max − min des largeurs valides
    demi_bande_px: int
    methodes: Dict[str, int]          # nombre de lignes par méthode
    raison_repli: Optional[str] = None

    @property
    def methode(self) -> str:
        """« masque », « canny » ou « mixte » si les deux ont servi."""
        utilisees = [m for m, n in self.methodes.items() if n]
        return utilisees[0] if len(utilisees) == 1 else METHODE_MIXTE


def demi_bande_px(hauteur_sujet_px: float,
                  fraction: float = DEMI_BANDE_FRACTION) -> int:
    """Demi-hauteur de la bande de mesure, en pixels (au moins 1)."""
    return max(1, int(round(abs(hauteur_sujet_px) * fraction)))


def ordonnees_lignes(y_centre: int, demi_bande: int,
                     n_lignes: int = N_LIGNES) -> List[int]:
    """Ordonnées de ``n_lignes`` lignes régulièrement espacées dans
    [y_centre − demi_bande, y_centre + demi_bande], doublons supprimés.

    La ligne centrale (niveau retenu) fait toujours partie de la liste
    lorsque ``n_lignes`` est impair.
    """
    if n_lignes < 1:
        raise ValueError("n_lignes doit être au moins 1.")
    if n_lignes == 1 or demi_bande <= 0:
        return [int(y_centre)]
    ys = np.linspace(y_centre - demi_bande, y_centre + demi_bande, n_lignes)
    return sorted({int(round(y)) for y in ys})


def mesurer_multilignes(image_bgr: np.ndarray, masque_proba: Optional[np.ndarray],
                        y_centre: int, x_ref: int, demi_bande: int,
                        n_lignes: int = N_LIGNES,
                        fraction_valides_min: float = FRACTION_LIGNES_VALIDES_MIN,
                        seuil: float = SEUIL_MASQUE) -> Optional[ResultatMultiLignes]:
    """Largeur médiane sur plusieurs lignes autour du niveau retenu (F-23).

    Chaque ligne est mesurée comme en A-04 (masque, Canny en repli). Les lignes
    sans résultat sont écartées ; la médiane des autres limite l'effet d'un
    bord mal détecté sur quelques lignes (bras touchant le tronc localement,
    ombre, pli de vêtement).

    Args:
        y_centre: niveau de mesure retenu, en pixels.
        x_ref: abscisse du milieu des hanches, en pixels.
        demi_bande: demi-hauteur de la bande, en pixels (voir ``demi_bande_px``).
        fraction_valides_min: part minimale de lignes valides ; en dessous la
            mesure est refusée plutôt que calculée sur une ou deux lignes.

    Returns:
        ResultatMultiLignes, ou None si trop peu de lignes sont valides.
    """
    largeur = image_bgr.shape[1]
    masque, raison_masque = preparer_masque(image_bgr, masque_proba,
                                            (x_ref, y_centre), seuil)
    canny = _BordsCanny(image_bgr)
    ys = ordonnees_lignes(y_centre, demi_bande, n_lignes)

    mesures = []
    for y in ys:
        res = _mesurer_ligne(masque, raison_masque, canny, y, x_ref, largeur)
        if res is not None:
            mesures.append((y, res))

    n_min = max(1, int(np.ceil(fraction_valides_min * len(ys))))
    if len(mesures) < n_min:
        return None

    largeurs = np.array([r.largeur_px for _, r in mesures], dtype=float)
    mediane = float(np.median(largeurs))
    # Ligne la plus proche de la médiane ; à égalité, la plus proche du centre.
    i = min(range(len(mesures)),
            key=lambda k: (abs(largeurs[k] - mediane), abs(mesures[k][0] - y_centre)))
    y_med, seg_med = mesures[i]

    methodes = {METHODE_MASQUE: 0, METHODE_CANNY: 0}
    for _, r in mesures:
        methodes[r.methode] += 1
    raisons = [r.raison_repli for _, r in mesures if r.raison_repli]
    raison = raisons[0] if raisons else None

    return ResultatMultiLignes(
        largeur_px=mediane,
        segment_median=seg_med,
        y_median=y_med,
        n_valides=len(mesures),
        n_lignes=len(ys),
        ecart_px=int(largeurs.max() - largeurs.min()),
        demi_bande_px=int(demi_bande),
        methodes=methodes,
        raison_repli=raison,
    )


def details_multilignes(resultat: Optional[ResultatMultiLignes],
                        n_lignes: Optional[int] = None) -> dict:
    """Traçabilité F-23 : mêmes clés qu'en A-04, plus le détail des lignes."""
    if resultat is None:
        return {
            "methode": None,
            "raison_repli": "trop peu de lignes de mesure valides",
            "lignes": {"n_valides": None, "n_total": n_lignes},
        }
    return {
        "methode": resultat.methode,
        "raison_repli": resultat.raison_repli,
        "lignes": {
            "n_valides": resultat.n_valides,
            "n_total": resultat.n_lignes,
            "ecart_px": resultat.ecart_px,
            "demi_bande_px": resultat.demi_bande_px,
            "par_methode": dict(resultat.methodes),
        },
    }


def details_segment(resultat: Optional[ResultatSegment]) -> dict:
    """Informations de traçabilité à renvoyer par l'API ou à journaliser."""
    if resultat is None:
        return {"methode": None, "raison_repli": "aucune méthode n'a abouti"}
    return {"methode": resultat.methode, "raison_repli": resultat.raison_repli}


def _borner(point: Tuple[int, int], largeur: int, hauteur: int) -> Tuple[int, int]:
    x, y = point
    return int(np.clip(x, 0, largeur - 1)), int(np.clip(y, 0, hauteur - 1))
