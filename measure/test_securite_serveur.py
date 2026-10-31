"""Tests A-05 – Sécurisation du serveur.

Lancer depuis la racine du dépôt :  python -m pytest measure -q

Les images de test sont générées en mémoire (aucune photo de personne dans le
dépôt). Le calcul MediaPipe est remplacé par un « faux » quand on veut simuler
un succès ou une exception.
"""
import io
import logging
import os
import re
import tempfile

import cv2
import numpy as np
import pytest

import app as server

FORM_OK = {
    "user_height_cm": "175",
    "patient_id": "PSEUDO-ABC123",
    "sex": "Female",
    "age": "30",
    "weight_kg": "60",
}


def jpeg_bytes(w=64, h=128):
    img = np.full((h, w, 3), 200, dtype=np.uint8)
    ok, buf = cv2.imencode(".jpg", img)
    assert ok
    return buf.tobytes()


def make_data(side=None, front=None, **overrides):
    data = {**FORM_OK, **overrides}
    data["image_side"] = (io.BytesIO(side if side is not None else jpeg_bytes()), "side.jpg")
    data["image_front"] = (io.BytesIO(front if front is not None else jpeg_bytes()), "front.jpg")
    return data


def snapshot(dirpath):
    return {
        os.path.join(root, f)
        for root, _dirs, files in os.walk(dirpath)
        for f in files
    }


@pytest.fixture
def client(tmp_path, monkeypatch):
    # Le serveur tourne dans un dossier vide : tout fichier créé s'y verrait.
    monkeypatch.chdir(tmp_path)
    server.app.config["TESTING"] = True
    with server.app.test_client() as c:
        yield c


@pytest.fixture
def no_new_files(tmp_path):
    """Vérifie qu'aucun fichier n'apparaît ni dans le dossier courant ni dans
    le dossier temporaire du système pendant le test."""
    sys_tmp = tempfile.gettempdir()
    before = snapshot(sys_tmp)
    yield
    assert snapshot(tmp_path) == set(), "un fichier a été écrit dans le dossier courant"
    assert not (tmp_path / "temp").exists()
    created = {p for p in snapshot(sys_tmp) - before if p.lower().endswith((".jpg", ".jpeg", ".png"))}
    assert created == set(), f"image(s) laissée(s) dans {sys_tmp}: {created}"


# --- /health ---------------------------------------------------------------

def test_health_repond_200(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.get_json() == {"status": "ok"}


# --- aucune image conservée ------------------------------------------------

def test_requete_reussie_ne_laisse_aucun_fichier(client, monkeypatch, no_new_files):
    def faux_calcul(side, front, height):
        assert isinstance(side, np.ndarray) and isinstance(front, np.ndarray)
        return {"waist_circumference": 80.0, "BRI": 3.1}

    monkeypatch.setattr(server, "calculer_bri", faux_calcul)
    r = client.post("/calculate-bri", data=make_data(), content_type="multipart/form-data")
    assert r.status_code == 200
    body = r.get_json()
    # contrat de l'API utilisé par l'appli Flutter
    assert set(body) == {"waist_circumference", "BRI"}


def test_exception_ne_laisse_aucun_fichier_ni_detail_interne(client, monkeypatch, no_new_files):
    def calcul_qui_plante(*_args):
        raise RuntimeError("detail interne secret /chemin/serveur")

    monkeypatch.setattr(server, "calculer_bri", calcul_qui_plante)
    r = client.post("/calculate-bri", data=make_data(), content_type="multipart/form-data")
    assert r.status_code == 500
    body = r.get_json()
    assert body["error"] == "Internal server error."
    assert "secret" not in r.get_data(as_text=True)
    assert "request_id" in body


def test_image_sans_personne_renvoie_400_sans_fichier(client, no_new_files):
    # Vrai calcul MediaPipe sur une image unie : aucune personne détectée.
    r = client.post("/calculate-bri", data=make_data(), content_type="multipart/form-data")
    assert r.status_code == 400
    assert "Unable to calculate BRI" in r.get_json()["error"]


# --- limites et validation des fichiers ------------------------------------

def test_fichier_trop_gros_rejete_413(client):
    trop_gros = b"\xff\xd8\xff" + b"0" * (server.app.config["MAX_CONTENT_LENGTH"] + 1)
    r = client.post("/calculate-bri", data=make_data(side=trop_gros), content_type="multipart/form-data")
    assert r.status_code == 413
    assert "error" in r.get_json()


@pytest.mark.parametrize("contenu", [
    b"ceci n'est pas une image",           # texte
    b"%PDF-1.4 faux pdf",                  # autre format
    b"\xff\xd8\xff" + b"jpeg corrompu",    # bonne signature, contenu illisible
    b"",                                   # fichier vide
])
def test_non_image_rejetee_400(client, contenu, no_new_files):
    r = client.post("/calculate-bri", data=make_data(front=contenu), content_type="multipart/form-data")
    assert r.status_code == 400
    assert r.get_json()["error"] == "Images must be valid JPEG or PNG files."


def test_png_accepte(client, monkeypatch):
    ok, buf = cv2.imencode(".png", np.zeros((32, 32, 3), dtype=np.uint8))
    monkeypatch.setattr(server, "calculer_bri", lambda *a: {"waist_circumference": 1.0, "BRI": 1.0})
    r = client.post("/calculate-bri", data=make_data(side=buf.tobytes()), content_type="multipart/form-data")
    assert r.status_code == 200


# --- journaux sans données personnelles ------------------------------------

def test_journaux_sans_donnees_personnelles(client, monkeypatch, caplog):
    caplog.set_level(logging.DEBUG)

    def calcul_qui_plante(*_args):
        raise ValueError("boom")

    monkeypatch.setattr(server, "calculer_bri", calcul_qui_plante)
    client.post("/calculate-bri", data=make_data(), content_type="multipart/form-data")
    monkeypatch.setattr(server, "calculer_bri", lambda *a: {"waist_circumference": 81.23, "BRI": 3.45})
    client.post("/calculate-bri", data=make_data(), content_type="multipart/form-data")

    # On ne garde que les messages, sans les champs techniques variables
    # (identifiant aléatoire, durée) qui pourraient contenir "60" par hasard.
    messages = [
        re.sub(r"request_id=\w+|duration_ms=\d+", "", m) for m in caplog.messages
    ]
    assert any("status=500" in m for m in messages)
    assert any("status=200" in m for m in messages)
    texte = "\n".join(messages)
    for valeur in ("PSEUDO-ABC123", "175", "Female", "female", "60", "81.23", "3.45"):
        assert valeur not in texte, f"donnée personnelle '{valeur}' dans les journaux"


# --- CORS (version web sur Netlify) ----------------------------------------

def test_cors_autorise_la_version_web(client):
    r = client.get("/health", headers={"Origin": "https://exemple.netlify.app"})
    assert r.headers["Access-Control-Allow-Origin"] == "*"


def test_cors_preflight_options(client):
    r = client.options(
        "/calculate-bri",
        headers={
            "Origin": "https://exemple.netlify.app",
            "Access-Control-Request-Method": "POST",
        },
    )
    assert r.status_code == 200
    assert "POST" in r.headers["Access-Control-Allow-Methods"]


# --- calcul réel du BRI à travers l'API ------------------------------------

def test_calcul_bri_complet_via_api(client, monkeypatch, no_new_files):
    """Seules les mesures d'image sont simulées : le calcul du tour de taille
    et la formule du BRI sont exécutés pour de vrai (régression : la route
    Flask calculate_bri masquait la formule du même nom -> TypeError, 500)."""
    monkeypatch.setattr(server, "mesurer_profondeur_taille", lambda img, h, d=None: 25.0)
    monkeypatch.setattr(server, "mesurer_largeur_taille", lambda img, h, d=None: 30.0)
    r = client.post("/calculate-bri", data=make_data(), content_type="multipart/form-data")
    assert r.status_code == 200, r.get_json()
    body = r.get_json()
    assert 60 < body["waist_circumference"] < 120
    assert 0 < body["BRI"] < 20
