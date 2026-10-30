"""Tests unitaires de la segmentation par masque avec repli Canny (A-04).

Les images et masques sont synthétiques : les tests n'appellent pas MediaPipe
et tournent en quelques millisecondes.

Lancer depuis la racine du dépôt :  python -m pytest measure -q
"""

import numpy as np
import pytest

try:
    from measure.segmentation import (
        METHODE_CANNY, METHODE_MASQUE, binariser_masque, controler_masque,
        controler_segment, details_segment, mesurer_segment, nettoyer_masque,
        segment_canny, segment_masque,
    )
except ImportError:  # lancé depuis le dossier measure/
    from segmentation import (
        METHODE_CANNY, METHODE_MASQUE, binariser_masque, controler_masque,
        controler_segment, details_segment, mesurer_segment, nettoyer_masque,
        segment_canny, segment_masque,
    )

H, W = 400, 300
Y = 200          # ligne de mesure
X_TRONC = 150    # milieu des hanches


def masque_tronc(x_g=110, x_d=190):
    """Masque de probabilités : un tronc vertical de x_g à x_d (exclu)."""
    m = np.zeros((H, W), dtype=np.float32)
    m[50:380, x_g:x_d] = 0.95
    return m


def image_tronc_raye(x_g=110, x_d=190):
    """Fond gris uni, tronc sombre avec des rayures claires (vêtement à motif).

    Les rayures créent des bords internes : Canny seul s'y arrête.
    """
    img = np.full((H, W, 3), 200, dtype=np.uint8)
    img[50:380, x_g:x_d] = 60
    for x in range(x_g + 10, x_d - 10, 12):
        img[50:380, x:x + 4] = 230
    return img


# --- Fonctions élémentaires ------------------------------------------------

def test_binariser_masque_seuil():
    m = np.array([[0.2, 0.5, 0.51, 0.9]], dtype=np.float32)
    assert binariser_masque(m).tolist() == [[0, 0, 1, 1]]


def test_binariser_masque_accepte_un_canal():
    m = np.full((4, 4, 1), 0.9, dtype=np.float32)
    assert binariser_masque(m).shape == (4, 4)


def test_segment_masque_largeur_exacte():
    masque = binariser_masque(masque_tronc(110, 190))
    assert segment_masque(masque, Y, X_TRONC) == (110, 190)  # 80 px


def test_segment_masque_ignore_les_bras_separes():
    masque = binariser_masque(masque_tronc(110, 190))
    masque[:, 60:100] = 1   # bras gauche, séparé du tronc par du fond
    masque[:, 200:240] = 1  # bras droit
    assert segment_masque(masque, Y, X_TRONC) == (110, 190)


def test_segment_masque_ancrage_dans_un_trou():
    masque = binariser_masque(masque_tronc(110, 190))
    masque[Y, 145:156] = 0  # petit trou au centre (ex. nombril)
    seg = segment_masque(masque, Y, X_TRONC)
    assert seg in {(110, 145), (156, 190)}


def test_segment_masque_ancrage_trop_loin():
    masque = binariser_masque(masque_tronc(110, 190))
    assert segment_masque(masque, Y, 20) is None


def test_segment_masque_ligne_hors_image():
    masque = binariser_masque(masque_tronc())
    assert segment_masque(masque, H + 5, X_TRONC) is None


def test_nettoyer_masque_garde_la_composante_du_sujet():
    masque = binariser_masque(masque_tronc(110, 190))
    masque[150:250, 230:290] = 1  # objet du décor pris pour une personne
    propre = nettoyer_masque(masque, (X_TRONC, Y))
    assert propre[Y, 260] == 0
    assert propre[Y, X_TRONC] == 1


def test_nettoyer_masque_supprime_le_bruit():
    masque = binariser_masque(masque_tronc())
    masque[10, 10] = 1  # pixel isolé
    propre = nettoyer_masque(masque, (X_TRONC, Y))
    assert propre[10, 10] == 0


@pytest.mark.parametrize("valeur, attendu_ok", [(0.0, False), (1.0, False)])
def test_controler_masque_vide_ou_plein(valeur, attendu_ok):
    m = np.full((H, W), valeur, dtype=np.uint8)
    assert (controler_masque(m) is None) == attendu_ok


def test_controler_masque_plausible():
    assert controler_masque(binariser_masque(masque_tronc())) is None


@pytest.mark.parametrize("segment, ok", [
    ((110, 190), True),
    (None, False),
    ((0, 190), False),        # touche le bord gauche
    ((110, W), False),        # touche le bord droit
    ((150, 152), False),      # trop étroit
    ((5, 295), False),        # trop large
])
def test_controler_segment(segment, ok):
    assert (controler_segment(segment, W) is None) == ok


def test_segment_canny_sans_bord_renvoie_none():
    gris = np.full((H, W), 128, dtype=np.uint8)
    # La V2 renvoyait alors toute la largeur de l'image.
    assert segment_canny(gris, Y, X_TRONC) is None


# --- Choix de la méthode -----------------------------------------------------

def test_masque_prioritaire_et_insensible_aux_motifs():
    img = image_tronc_raye(110, 190)
    res = mesurer_segment(img, masque_tronc(110, 190), Y, X_TRONC)
    assert res.methode == METHODE_MASQUE
    assert res.raison_repli is None
    assert res.largeur_px == 80


def test_canny_seul_se_trompe_sur_les_motifs():
    """Montre la limite corrigée par A-04 : Canny s'arrête sur une rayure."""
    import cv2
    gris = cv2.cvtColor(image_tronc_raye(110, 190), cv2.COLOR_BGR2GRAY)
    x_g, x_d = segment_canny(gris, Y, X_TRONC)
    assert x_d - x_g < 40  # bien moins que les 80 px réels


def test_repli_canny_si_masque_absent():
    img = np.full((H, W, 3), 200, dtype=np.uint8)
    img[50:380, 110:190] = 60  # tronc uni : Canny suffit
    res = mesurer_segment(img, None, Y, X_TRONC)
    assert res.methode == METHODE_CANNY
    assert res.raison_repli == "masque absent"
    assert abs(res.largeur_px - 80) <= 2


def test_repli_canny_si_masque_vide():
    img = np.full((H, W, 3), 200, dtype=np.uint8)
    img[50:380, 110:190] = 60
    res = mesurer_segment(img, np.zeros((H, W), np.float32), Y, X_TRONC)
    assert res.methode == METHODE_CANNY
    assert "vide" in res.raison_repli


def test_repli_canny_si_masque_touche_le_bord():
    img = np.full((H, W, 3), 200, dtype=np.uint8)
    img[50:380, 110:190] = 60
    masque = np.zeros((H, W), np.float32)
    masque[150:250, 0:200] = 0.9  # silhouette coupée par le cadre
    res = mesurer_segment(img, masque, Y, X_TRONC)
    assert res.methode == METHODE_CANNY
    assert "bord" in res.raison_repli


def test_repli_canny_si_masque_de_mauvaise_taille():
    img = np.full((H, W, 3), 200, dtype=np.uint8)
    img[50:380, 110:190] = 60
    res = mesurer_segment(img, np.ones((10, 10), np.float32), Y, X_TRONC)
    assert res.methode == METHODE_CANNY


def test_echec_des_deux_methodes():
    img = np.full((H, W, 3), 200, dtype=np.uint8)  # rien à détecter
    assert mesurer_segment(img, None, Y, X_TRONC) is None


def test_details_segment():
    img = image_tronc_raye()
    res = mesurer_segment(img, masque_tronc(), Y, X_TRONC)
    assert details_segment(res) == {"methode": "masque", "raison_repli": None}
    assert details_segment(None)["methode"] is None
