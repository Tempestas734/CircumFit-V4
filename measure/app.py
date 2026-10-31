import logging
import math
import os
import time
import uuid

# A-05 : plafond du nombre de pixels décodés par OpenCV (protection contre les
# images « bombes » qui satureraient la mémoire). Doit être fixé AVANT import cv2.
os.environ.setdefault("OPENCV_IO_MAX_IMAGE_PIXELS", str(40_000_000))

import cv2
import mediapipe as mp
import numpy as np
from flask import Flask, jsonify, request
from werkzeug.exceptions import HTTPException

try:  # import en tant que paquet (gunicorn measure.app:app) ou en script
    from .segmentation import details_multilignes, demi_bande_px, mesurer_multilignes
    from .circumference import (
        calculate_body_roundness_index,
        estimate_waist_circumference,
    )
except ImportError:
    from segmentation import details_multilignes, demi_bande_px, mesurer_multilignes
    from circumference import (
        calculate_body_roundness_index,
        estimate_waist_circumference,
    )

# Initialisation de MediaPipe Pose
mp_pose = mp.solutions.pose

# Initialiser l'application Flask
app = Flask(__name__)

# A-05 : taille maximale de la requête complète (2 photos + champs).
# Au-delà, Flask renvoie 413 avant même de lire les fichiers.
MAX_UPLOAD_MB = 20
app.config["MAX_CONTENT_LENGTH"] = MAX_UPLOAD_MB * 1024 * 1024

# A-05 : signatures acceptées (JPEG, PNG) — vérifiées en plus du décodage.
_IMAGE_SIGNATURES = (b"\xff\xd8\xff", b"\x89PNG\r\n\x1a\n")


@app.after_request
def add_cors_headers(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type"
    return response


# A-05 : journaux SANS données personnelles. On ne journalise jamais les champs
# du formulaire (patient_id, sexe, âge, poids, taille), ni les images, ni les
# résultats ; seulement un identifiant de requête aléatoire, le statut, la durée
# et le type d'erreur éventuel.
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
logger = logging.getLogger("circumfit.api")


class InvalidImageError(ValueError):
    """Fichier reçu absent, vide, ou qui n'est pas une image JPEG/PNG lisible."""


def decoder_image(file_storage):
    """Décode une image envoyée en multipart directement en mémoire.

    Aucune écriture sur disque : les octets sont lus en RAM, décodés par
    OpenCV, puis libérés par le ramasse-miettes à la fin de la requête.
    """
    data = file_storage.read()
    if not data or not data.startswith(_IMAGE_SIGNATURES):
        raise InvalidImageError()
    image = cv2.imdecode(np.frombuffer(data, dtype=np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise InvalidImageError()
    return image

def mesurer_profondeur_taille(image, user_height_cm, details=None):
    """
    Calcule la profondeur (largeur latérale) de la taille d'une personne en vue latérale.

    Args:
        image: Image de profil déjà décodée (tableau BGR OpenCV, en mémoire).
        user_height_cm: Hauteur réelle de la personne en centimètres.
        details: dict optionnel complété avec la méthode de segmentation
            utilisée ("masque" ou "canny") et la raison d'un repli.

    Returns:
        Largeur complète de la taille en centimètres (pas un demi-axe),
        ou None si les points clés ne sont pas détectés.
    """
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

    # Initialisation de MediaPipe Pose
    with mp_pose.Pose(static_image_mode=True, min_detection_confidence=0.5,
                      enable_segmentation=True) as pose:
        results = pose.process(image_rgb)
        if results.pose_landmarks is None:
            return None

        landmarks = results.pose_landmarks.landmark
        height, width, _ = image.shape

        # Points clés nécessaires
        left_heel = landmarks[mp_pose.PoseLandmark.LEFT_HEEL]
        right_heel = landmarks[mp_pose.PoseLandmark.RIGHT_HEEL]
        left_shoulder = landmarks[mp_pose.PoseLandmark.LEFT_SHOULDER]
        right_shoulder = landmarks[mp_pose.PoseLandmark.RIGHT_SHOULDER]
        nose = landmarks[mp_pose.PoseLandmark.NOSE]
        left_hip = landmarks[mp_pose.PoseLandmark.LEFT_HIP]
        right_hip = landmarks[mp_pose.PoseLandmark.RIGHT_HIP]

        # Calcul des coordonnées du sommet de la tête à partir de la distance nez-talons
        heel_y_px = int(((left_heel.y + right_heel.y) / 2) * height)
        nose_y = int(nose.y * height)
        distance_nose_heel = nose_y - heel_y_px
            
        head_y = int(nose_y + (0.1 * distance_nose_heel)) # 10 % ajouté pour estimer la tête
        head_x = int(left_hip.x * width)

        # Tracer le sommet de la tête
        cv2.drawMarker(image, (head_x, head_y), (255, 0, 0), markerType=cv2.MARKER_STAR, thickness=2)
        cv2.putText(image, "Head (estimated)", (head_x + 10, head_y - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 0, 0), 2)
            
        # Calcul de la hauteur totale et du ratio pixel/cm
        person_height_px = abs(heel_y_px - head_y)
        ratio_pixel_cm = user_height_cm / person_height_px

        # Position de la taille à 25 % de la distance épaules-talons
        shoulder_y_px = int(((left_shoulder.y + right_shoulder.y) / 2) * height)
        distance_epaules_talons = abs(heel_y_px - shoulder_y_px)
        waist_y_px = int(shoulder_y_px + (distance_epaules_talons * 0.25))

        # Bords de la silhouette sur la ligne de mesure (A-04) : masque de
        # segmentation MediaPipe en priorité, Canny en repli. Le balayage part
        # du milieu des hanches (centre du tronc) et non du centre de l'image.
        x_tronc = int(((left_hip.x + right_hip.x) / 2) * width)
        segment = mesurer_multilignes(
            image,
            results.segmentation_mask,
            waist_y_px,
            x_tronc,
            demi_bande_px(person_height_px),
        )
        if details is not None:
            details.update(details_multilignes(segment))
        if segment is None:
            print("Bords de la silhouette introuvables autour de la ligne de mesure.")
            return None

        # La mesure multi-lignes fournit la largeur médiane en pixels.
        waist_width_px = segment.largeur_px
        waist_width_cm = waist_width_px * ratio_pixel_cm

        return waist_width_cm
    pass

def mesurer_largeur_taille(image, user_height_cm, details=None):
    """
    Calcule la largeur de la taille en centimètres pour une vue frontale de la personne.

    Args:
        image: Image frontale déjà décodée (tableau BGR OpenCV, en mémoire).
        user_height_cm: Hauteur réelle de la personne en centimètres.
        details: dict optionnel complété avec la méthode de segmentation
            utilisée ("masque" ou "canny") et la raison d'un repli.

    Returns:
        Largeur complète de la taille en centimètres (pas un demi-axe),
        ou None si les points clés ne sont pas détectés.
    """
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

    # Initialisation de MediaPipe Pose
    with mp_pose.Pose(static_image_mode=True, min_detection_confidence=0.5,
                      enable_segmentation=True) as pose:
        results = pose.process(image_rgb)
        if results.pose_landmarks is None:
            return None

        landmarks = results.pose_landmarks.landmark
        height, width, _ = image.shape
            
        # Points clés nécessaires
        left_heel = landmarks[mp_pose.PoseLandmark.LEFT_HEEL]
        right_heel = landmarks[mp_pose.PoseLandmark.RIGHT_HEEL]
        left_shoulder = landmarks[mp_pose.PoseLandmark.LEFT_SHOULDER]
        right_shoulder = landmarks[mp_pose.PoseLandmark.RIGHT_SHOULDER]
        nose = landmarks[mp_pose.PoseLandmark.NOSE]
        left_hip = landmarks[mp_pose.PoseLandmark.LEFT_HIP]
        right_hip = landmarks[mp_pose.PoseLandmark.RIGHT_HIP]

        # Calcul des coordonnées importantes
        shoulder_y_px = int(((left_shoulder.y + right_shoulder.y) / 2) * height)
        heel_y_px = int(((left_heel.y + right_heel.y) / 2) * height)
        nose_y = int(nose.y * height)
        distance_nose_heel = nose_y - heel_y_px
        head_y = int(nose_y + (0.1 * distance_nose_heel))  # 10 % ajouté pour estimer la tête
        head_x = int(nose.x * width)

        # Tracer le sommet de la tête
        cv2.drawMarker(image, (head_x, head_y), (255, 0, 0), markerType=cv2.MARKER_STAR, thickness=2)
        cv2.putText(image, "Head (estimated)", (head_x + 10, head_y - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 0, 0), 2)
            
        # Calcul de la hauteur totale et du ratio pixel/cm
        person_height_px = abs(heel_y_px - head_y)
        ratio_pixel_cm = user_height_cm / person_height_px

        # Position de la taille à 25 % de la distance épaules-talons
        distance_epaules_talons = abs(heel_y_px - shoulder_y_px)
        waist_y_px = int(shoulder_y_px + (distance_epaules_talons * 0.25))

        # Bords de la silhouette sur la ligne de mesure (A-04) : masque de
        # segmentation MediaPipe en priorité, Canny en repli. Le balayage part
        # du milieu des hanches (centre du tronc) et non du centre de l'image.
        x_tronc = int(((left_hip.x + right_hip.x) / 2) * width)
        segment = mesurer_multilignes(
            image,
            results.segmentation_mask,
            waist_y_px,
            x_tronc,
            demi_bande_px(person_height_px),
        )
        if details is not None:
            details.update(details_multilignes(segment))
        if segment is None:
            print("Bords de la silhouette introuvables autour de la ligne de mesure.")
            return None

        # La mesure multi-lignes fournit la largeur médiane en pixels.
        waist_width_px = segment.largeur_px
        waist_width_cm = waist_width_px * ratio_pixel_cm

        return waist_width_cm
        
    pass


def calculer_bri(image_side, image_front, user_height_cm):
    segmentation = {"profil": {}, "face": {}}
    profondeur_laterale_cm = mesurer_profondeur_taille(
        image_side, user_height_cm, segmentation["profil"]
    )
    largeur_frontale_cm = mesurer_largeur_taille(
        image_front, user_height_cm, segmentation["face"]
    )

    if profondeur_laterale_cm and largeur_frontale_cm:
        waist_circumference = estimate_waist_circumference(
            largeur_frontale_cm,
            profondeur_laterale_cm,
        )

        try:
            BRI = calculate_body_roundness_index(
                waist_circumference, user_height_cm
            )
        except ValueError:
            return None
        return {
            "waist_circumference": waist_circumference,
            "BRI": BRI,
            # Méthode de détection des bords par vue (A-04), pour la traçabilité.
            "segmentation": segmentation,
        }
    else:
        return None
    
    
@app.route('/health', methods=['GET'])
def health():
    """Sonde de disponibilité (Render, ping de maintien en éveil). Ne charge
    aucun modèle et ne touche à aucune donnée."""
    return jsonify({"status": "ok"}), 200


@app.errorhandler(413)
def request_too_large(_error):
    logger.info("request rejected: payload too large (413)")
    return jsonify({
        "error": f"Request too large (max {MAX_UPLOAD_MB} MB for both images)."
    }), 413


@app.route('/calculate-bri', methods=['POST'])
def calculate_bri():
    request_id = uuid.uuid4().hex[:12]
    started = time.monotonic()

    def done(payload, status):
        logger.info(
            "request_id=%s status=%s duration_ms=%d",
            request_id, status, (time.monotonic() - started) * 1000,
        )
        return jsonify(payload), status

    try:
        required_fields = (
            'patient_id',
            'sex',
            'age',
            'weight_kg',
            'user_height_cm',
        )
        missing_fields = [
            field for field in required_fields if not request.form.get(field)
        ]
        if (
            missing_fields
            or 'image_side' not in request.files
            or 'image_front' not in request.files
        ):
            return done({
                "error": "Missing required patient data or images.",
                "missing_fields": missing_fields,
            }, 400)

        # Valider les données patient transmises par le formulaire.
        # NB (minimisation) : patient_id, sexe, âge et poids sont validés mais
        # ne sont pas utilisés par le calcul ; ils ne sont ni stockés ni
        # journalisés.
        patient_id = request.form['patient_id'].strip()
        sex = request.form['sex'].strip().lower()
        try:
            user_height_cm = float(request.form['user_height_cm'])
            age = int(request.form['age'])
            weight_kg = float(request.form['weight_kg'])
        except ValueError:
            return done({
                "error": "Height, age, and weight must be valid numbers."
            }, 400)
        if not patient_id:
            return done({"error": "Patient ID must not be empty."}, 400)
        if sex not in {'male', 'female'}:
            return done({"error": "Sex must be male or female."}, 400)
        if not math.isfinite(user_height_cm) or not 100 <= user_height_cm <= 230:
            return done({
                "error": "Height must be between 100 and 230 cm."
            }, 400)
        if age <= 0:
            return done({"error": "Age must be a positive whole number."}, 400)
        if not math.isfinite(weight_kg) or weight_kg <= 0:
            return done({"error": "Weight must be a positive number."}, 400)

        # Décodage en mémoire : aucune image n'est jamais écrite sur disque,
        # donc rien ne peut rester sur le serveur, même en cas d'erreur, et
        # deux requêtes simultanées ne peuvent pas s'écraser.
        try:
            image_side = decoder_image(request.files['image_side'])
            image_front = decoder_image(request.files['image_front'])
        except InvalidImageError:
            return done({
                "error": "Images must be valid JPEG or PNG files."
            }, 400)

        # Calculer le BRI
        result = calculer_bri(image_side, image_front, user_height_cm)

        if result:
            return done(result, 200)
        return done({
            "error": "Unable to calculate BRI. Ensure the images are correct."
        }, 400)
    except HTTPException:
        # Erreurs HTTP prévues (ex. 413 fichier trop gros) : gérées par les
        # errorhandler de Flask, pas transformées en 500.
        raise
    except Exception as e:
        # Détail technique uniquement dans les journaux (type + pile d'appels,
        # sans les valeurs du formulaire) ; message générique côté client.
        logger.error(
            "request_id=%s unexpected %s", request_id, type(e).__name__,
            exc_info=True,
        )
        return done({
            "error": "Internal server error.",
            "request_id": request_id,
        }, 500)


if __name__ == '__main__':
    # Lancement local uniquement (en production, Render utilise gunicorn).
    port = int(os.environ.get('PORT', 5000))
    app.run(debug=False, host='0.0.0.0', port=port)
