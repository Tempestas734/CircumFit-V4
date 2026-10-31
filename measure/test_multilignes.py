"""Tests unitaires de la mesure multi-lignes avec médiane (F-23).

Images et masques synthétiques : pas d'appel à MediaPipe, pas de photo.

Lancer depuis la racine du dépôt :  python -m pytest measure -q
"""

import numpy as np
import pytest

try:
    from measure.segmentation import (
        METHODE_CANNY, METHODE_MASQUE, METHODE_MIXTE, demi_bande_px,
        details_multilignes, mesurer_multilignes, mesurer_segment,
        ordonnees_lignes,
    )
except ImportError:  # lancé depuis le dossier measure/
    from segmentation import (
        METHODE_CANNY, METHODE_MASQUE, METHODE_MIXTE, demi_bande_px,
        details_multilignes, mesurer_multilignes, mesurer_segment,
        ordonnees_lignes,
    )

H, W = 400, 300
Y = 200          # niveau de mesure retenu
X_TRONC = 150    # milieu des hanches
DEMI_BANDE = 40  # lignes à 160, 170, ..., 240 avec 9 lignes


def masque_tronc(x_g=110, x_d=190):
    """Masque de probabilités : un tronc vertical de x_g à x_d (exclu), 80 px."""
    m = np.zeros((H, W), dtype=np.float32)
    m[50:380, x_g:x_d] = 0.95
    return m


def image_fond():
    return np.full((H, W, 3), 200, dtype=np.uint8)


def image_tronc_uni(x_g=110, x_d=190):
    img = image_fond()
    img[50:380, x_g:x_d] = 60
    return img


# --- Choix des lignes --------------------------------------------------------

def test_ordonnees_lignes_regulieres_et_centrees():
    assert ordonnees_lignes(Y, DEMI_BANDE, 9) == list(range(160, 241, 10))


def test_ordonnees_lignes_une_seule():
    assert ordonnees_lignes(Y, DEMI_BANDE, 1) == [Y]
    assert ordonnees_lignes(Y, 0, 9) == [Y]


def test_ordonnees_lignes_sans_doublons_si_bande_etroite():
    ys = ordonnees_lignes(Y, 2, 9)
    assert ys == sorted(set(ys)) == [198, 199, 200, 201, 202]


def test_ordonnees_lignes_refuse_zero_ligne():
    with pytest.raises(ValueError):
        ordonnees_lignes(Y, DEMI_BANDE, 0)


def test_demi_bande_proportionnelle_a_la_hauteur_du_sujet():
    assert demi_bande_px(3000) == 60     # 2 % de la hauteur
    assert demi_bande_px(330) == 7
    assert demi_bande_px(10) == 1        # jamais nulle


# --- Médiane -----------------------------------------------------------------

def test_tronc_regulier_meme_resultat_que_une_ligne():
    """Non-régression : sur un tronc régulier, F-23 retrouve A-04."""
    img, m = image_tronc_uni(), masque_tronc()
    une = mesurer_segment(img, m, Y, X_TRONC)
    multi = mesurer_multilignes(img, m, Y, X_TRONC, DEMI_BANDE)
    assert multi.largeur_px == une.largeur_px == 80
    assert multi.n_valides == multi.n_lignes == 9
    assert multi.ecart_px == 0
    assert multi.methode == METHODE_MASQUE


def test_une_ligne_seule_identique_a_A04():
    img, m = image_tronc_uni(), masque_tronc()
    multi = mesurer_multilignes(img, m, Y, X_TRONC, DEMI_BANDE, n_lignes=1)
    une = mesurer_segment(img, m, Y, X_TRONC)
    assert multi.n_lignes == 1
    assert multi.largeur_px == une.largeur_px
    assert multi.segment_median == une


def test_mediane_ignore_un_bras_colle_sur_quelques_lignes():
    """Bras touchant le tronc sur 2 lignes sur 9 : la médiane l'ignore."""
    m = masque_tronc()
    m[158:173, 70:110] = 0.95  # bras collé au flanc gauche (lignes 160 et 170)
    img = image_tronc_uni()
    une = mesurer_segment(img, m, 160, X_TRONC)
    multi = mesurer_multilignes(img, m, Y, X_TRONC, DEMI_BANDE)
    assert une.largeur_px == 120          # une seule ligne : bras inclus
    assert multi.largeur_px == 80         # médiane : bras écarté
    assert multi.ecart_px == 40           # l'écart signale le problème
    assert multi.segment_median.largeur_px == 80
    assert multi.y_median not in (160, 170)


def test_mediane_ignore_un_trou_du_masque():
    """Masque rogné sur quelques lignes (ombre, vêtement sombre)."""
    m = masque_tronc()
    m[225:245, 110:135] = 0.0  # coin rongé sur les lignes 230 et 240
    multi = mesurer_multilignes(image_tronc_uni(), m, Y, X_TRONC, DEMI_BANDE)
    assert multi.largeur_px == 80


def test_tronc_qui_s_elargit_donne_la_largeur_du_milieu():
    """Silhouette en trapèze : la médiane vaut la largeur au niveau retenu."""
    m = np.zeros((H, W), dtype=np.float32)
    for y in range(50, 380):
        demi = 40 + (y - Y) // 10  # 1 px de plus de chaque côté tous les 10 px
        m[y, X_TRONC - demi:X_TRONC + demi] = 0.95
    multi = mesurer_multilignes(image_fond(), m, Y, X_TRONC, DEMI_BANDE)
    assert multi.largeur_px == 80
    assert multi.y_median == Y


# --- Refus et repli ------------------------------------------------------------

def test_lignes_hors_image_ecartees():
    """Bande qui dépasse le bas de l'image : seules les lignes dans l'image comptent."""
    m = np.zeros((H, W), dtype=np.float32)
    m[200:H, 110:190] = 0.95
    img = image_fond()
    img[200:H, 110:190] = 60
    multi = mesurer_multilignes(img, m, H - 10, X_TRONC, 20, n_lignes=9)
    assert multi is not None
    assert multi.n_valides < multi.n_lignes
    assert multi.largeur_px == 80


def test_refus_si_trop_peu_de_lignes_valides():
    """Masque présent sur 2 lignes sur 9 seulement : mesure refusée (None)."""
    m = np.zeros((H, W), dtype=np.float32)
    m[50:175, 110:190] = 0.95  # le tronc s'arrête au-dessus de 175
    img = image_fond()          # Canny n'a rien à détecter
    img[50:175, 110:190] = 60
    assert mesurer_multilignes(img, m, Y, X_TRONC, DEMI_BANDE) is None


def test_echec_complet_renvoie_none():
    assert mesurer_multilignes(image_fond(), None, Y, X_TRONC, DEMI_BANDE) is None


def test_repli_canny_sur_toutes_les_lignes():
    multi = mesurer_multilignes(image_tronc_uni(), None, Y, X_TRONC, DEMI_BANDE)
    assert multi.methode == METHODE_CANNY
    assert multi.raison_repli == "masque absent"
    assert abs(multi.largeur_px - 80) <= 2


def test_methode_mixte_si_masque_echoue_sur_une_ligne():
    m = masque_tronc()
    m[Y - 3:Y + 4, :] = 0.95  # masque jusqu'au bord sur la ligne centrale seulement
    img = image_tronc_uni()   # Canny prend le relais sur cette ligne
    multi = mesurer_multilignes(img, m, Y, X_TRONC, DEMI_BANDE)
    assert multi.methode == METHODE_MIXTE
    assert multi.methodes[METHODE_CANNY] == 1
    assert multi.methodes[METHODE_MASQUE] == 8
    assert multi.raison_repli is not None
    assert multi.largeur_px == 80


# --- Traçabilité -------------------------------------------------------------

def test_details_multilignes():
    multi = mesurer_multilignes(image_tronc_uni(), masque_tronc(), Y, X_TRONC, DEMI_BANDE)
    d = details_multilignes(multi)
    assert d["methode"] == "masque"
    assert d["raison_repli"] is None
    assert d["lignes"] == {
        "n_valides": 9, "n_total": 9, "ecart_px": 0, "demi_bande_px": 40,
        "par_methode": {"masque": 9, "canny": 0},
    }


def test_details_multilignes_echec():
    d = details_multilignes(None, n_lignes=9)
    assert d["methode"] is None
    assert d["lignes"] == {"n_valides": None, "n_total": 9}
