from flask import Flask, request, jsonify
import cv2
import mediapipe as mp
import numpy as np
import math
try:  # import en tant que paquet (gunicorn measure.app:app) ou en script
    from .segmentation import details_segment, mesurer_segment
except ImportError:
    from segmentation import details_segment, mesurer_segment
import os

# Initialisation de MediaPipe Pose
mp_pose = mp.solutions.pose

# Initialiser l'application Flask
app = Flask(__name__)

def mesurer_profondeur_taille(image_path, user_height_cm, details=None):
    """
    Calcule la profondeur (largeur latérale) de la taille d'une personne en vue latérale.

    Args:
        image_path: Chemin vers l'image de profile.
        user_height_cm: Hauteur réelle de la personne en centimètres.
        details: dict optionnel complété avec la méthode de segmentation
            utilisée ("masque" ou "canny") et la raison d'un repli.

    Returns:
        Largeur complète de la taille en centimètres (pas un demi-axe),
        ou None si les points clés ne sont pas détectés.
    """
    # Charger l'image
    image = cv2.imread(image_path)
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
        segment = mesurer_segment(image, results.segmentation_mask, waist_y_px, x_tronc)
        if details is not None:
            details.update(details_segment(segment))
        if segment is None:
            print("Bords de la silhouette introuvables sur la ligne de mesure.")
            return None

        # Conversion de la largeur de la taille en centimètres
        waist_width_px = segment.largeur_px
        waist_width_cm = waist_width_px * ratio_pixel_cm

        return waist_width_cm
    pass

def mesurer_largeur_taille(image_path, user_height_cm, details=None):
    """
    Calcule la largeur de la taille en centimètres pour une vue frontale de la personne.

    Args:
        image_path: Chemin vers l'image frontale.
        user_height_cm: Hauteur réelle de la personne en centimètres.
        details: dict optionnel complété avec la méthode de segmentation
            utilisée ("masque" ou "canny") et la raison d'un repli.

    Returns:
        Largeur complète de la taille en centimètres (pas un demi-axe),
        ou None si les points clés ne sont pas détectés.
    """
    # Charger l'image
    image = cv2.imread(image_path)
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
        segment = mesurer_segment(image, results.segmentation_mask, waist_y_px, x_tronc)
        if details is not None:
            details.update(details_segment(segment))
        if segment is None:
            print("Bords de la silhouette introuvables sur la ligne de mesure.")
            return None

        # Conversion de la largeur de la taille en centimètres
        waist_width_px = segment.largeur_px
        waist_width_cm = waist_width_px * ratio_pixel_cm

        return waist_width_cm
        
    pass


def calculer_bri(image_path_side, image_path_front, user_height_cm):
    segmentation = {"profil": {}, "face": {}}
    profondeur_laterale_cm = mesurer_profondeur_taille(
        image_path_side, user_height_cm, segmentation["profil"]
    )
    largeur_frontale_cm = mesurer_largeur_taille(
        image_path_front, user_height_cm, segmentation["face"]
    )

    if profondeur_laterale_cm and largeur_frontale_cm:
        # r1 et r2 sont les demi-axes, calculés à partir des largeurs complètes.
        r1 = largeur_frontale_cm / 2  # demi-axe frontal
        r2 = profondeur_laterale_cm / 2  # demi-axe latéral
        waist_circumference = 2 * math.pi * math.sqrt(
            (r1**2 + r2**2) / 2
        )

        # Calcul du BRI
        BRI = 364.2 - 365.5 * ((1 - (waist_circumference / (math.pi * user_height_cm))**2))**0.5
        return {
            "waist_circumference": waist_circumference,
            "BRI": BRI,
            # Méthode de détection des bords par vue (A-04), pour la traçabilité.
            "segmentation": segmentation,
        }
    else:
        return None
    
    
@app.route('/calculate-bri', methods=['POST'])
def calculate_bri():
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
            return jsonify({
                "error": "Missing required patient data or images.",
                "missing_fields": missing_fields,
            }), 400

        # Valider les données patient transmises par le formulaire.
        patient_id = request.form['patient_id'].strip()
        sex = request.form['sex'].strip().lower()
        try:
            user_height_cm = float(request.form['user_height_cm'])
            age = int(request.form['age'])
            weight_kg = float(request.form['weight_kg'])
        except ValueError:
            return jsonify({
                "error": "Height, age, and weight must be valid numbers."
            }), 400
        if not patient_id:
            return jsonify({"error": "Patient ID must not be empty."}), 400
        if sex not in {'male', 'female'}:
            return jsonify({"error": "Sex must be male or female."}), 400
        if not math.isfinite(user_height_cm) or not 100 <= user_height_cm <= 230:
            return jsonify({
                "error": "Height must be between 100 and 230 cm."
            }), 400
        if age <= 0:
            return jsonify({"error": "Age must be a positive whole number."}), 400
        if not math.isfinite(weight_kg) or weight_kg <= 0:
            return jsonify({"error": "Weight must be a positive number."}), 400

        image_side = request.files['image_side']
        image_front = request.files['image_front']

        # Sauvegarder temporairement les images
        side_path = os.path.join("temp", "side.jpg")
        front_path = os.path.join("temp", "front.jpg")
        os.makedirs("temp", exist_ok=True)
        image_side.save(side_path)
        image_front.save(front_path)

        # Calculer le BRI
        result = calculer_bri(side_path, front_path, user_height_cm)

        # Supprimer les fichiers temporaires
        os.remove(side_path)
        os.remove(front_path)

        if result:
            return jsonify(result)
        else:
            return jsonify({"error": "Unable to calculate BRI. Ensure the images are correct."}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))  # Récupère le port assigné par Render
    app.run(debug=True, host='0.0.0.0', port=port)