import cv2
import mediapipe as mp
import numpy as np
import math

# Initialisation de MediaPipe Pose
mp_pose = mp.solutions.pose

def tracer_points(image, landmarks, width, height):
    """
    Trace les points clés détectés par MediaPipe sur l'image avec des croix rouges.

    Args:
        image: Image sur laquelle tracer les points.
        landmarks: Points clés détectés par MediaPipe.
        width: Largeur de l'image.
        height: Hauteur de l'image.
    """
    for landmark in landmarks:
        x = int(landmark.x * width)
        y = int(landmark.y * height)
        cv2.drawMarker(image, (x, y), (0, 0, 255), markerType=cv2.MARKER_CROSS, thickness=2)

        
def mesurer_profondeur_taille(image_path, user_height_cm, image_name="output"):
    """
    Calcule la profondeur (largeur latérale) de la taille d'une personne en vue latérale.

    Args:
        image_path: Chemin vers l'image de profile.
        user_height_cm: Hauteur réelle de la personne en centimètres.
        image_name: Nom pour sauvegarder l'image annotée.

    Returns:
        Largeur complète de la taille en centimètres (pas un demi-axe),
        ou None si les points clés ne sont pas détectés.
    """
    # Charger l'image
    image = cv2.imread(image_path)
    if image is None:
        raise FileNotFoundError("Image introuvable.")
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

    # Initialisation de MediaPipe Pose
    with mp_pose.Pose(static_image_mode=True, min_detection_confidence=0.5) as pose:
        results = pose.process(image_rgb)

        if results.pose_landmarks:
            landmarks = results.pose_landmarks.landmark
            height, width, _ = image.shape
            tracer_points(image, landmarks, width, height)

            # Points clés nécessaires
            left_heel = landmarks[mp_pose.PoseLandmark.LEFT_HEEL]
            right_heel = landmarks[mp_pose.PoseLandmark.RIGHT_HEEL]
            left_shoulder = landmarks[mp_pose.PoseLandmark.LEFT_SHOULDER]
            right_shoulder = landmarks[mp_pose.PoseLandmark.RIGHT_SHOULDER]
            nose = landmarks[mp_pose.PoseLandmark.NOSE]
            left_hip = landmarks[mp_pose.PoseLandmark.LEFT_HIP]

            # Calcul des coordonnées du sommet de la tête à partir de la distance nez-talons
            heel_y_px = int(((left_heel.y + right_heel.y) / 2) * height)
            nose_y = int(nose.y * height)
            distance_nose_heel = nose_y - heel_y_px
            
            head_y = int(nose_y + (0.1 * distance_nose_heel))  # 10 % ajouté pour estimer la tête
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

            # Calcul de la largeur de la taille en pixels
            edges = cv2.Canny(cv2.cvtColor(image, cv2.COLOR_BGR2GRAY), 50, 150)
            cv2.imwrite("edges_profil.png",edges)
            # détection de contours
            x_center = int(width/2)
            x_left, x_right = x_center, x_center
            # part du point central et incrémente de part et d'autres jusqu'à détecter un contour de la silouhette (ligne de la largeur de la taille )
            while x_left > 0 and edges[waist_y_px, x_left] == 0:
                x_left -= 1
            while x_right < width and edges[waist_y_px, x_right] == 0:
                x_right += 1

            # Conversion de la largeur de la taille en centimètres
            waist_width_px = x_right - x_left
            waist_width_cm = waist_width_px * ratio_pixel_cm

            # Annoter et sauvegarde l'image avec les résultats
            cv2.line(image, (x_left, waist_y_px), (x_right, waist_y_px), (0, 255, 0), 3)
            cv2.putText(image, f"{waist_width_cm:.2f} cm", (x_center, waist_y_px - 20),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
            output_path = f"{image_name}_mesure_side.png"
            cv2.imwrite(output_path, image)

            print(f"Profondeur de la taille : {waist_width_cm:.2f} cm")
            return waist_width_cm
        else:
            print("Aucun point de repère détecté.")
            return None


def mesurer_largeur_taille(image_path, user_height_cm, image_name="output"):
    """
    Calcule la largeur de la taille en centimètres pour une vue frontale de la personne.

    Args:
        image_path: Chemin vers l'image frontale.
        user_height_cm: Hauteur réelle de la personne en centimètres.
        image_name: Nom pour sauvegarder l'image annotée.

    Returns:
        Largeur complète de la taille en centimètres (pas un demi-axe),
        ou None si les points clés ne sont pas détectés.
    """
    # Charger l'image
    image = cv2.imread(image_path)
    if image is None:
        raise FileNotFoundError("Image introuvable.")
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

    # Initialisation de MediaPipe Pose
    with mp_pose.Pose(static_image_mode=True, min_detection_confidence=0.5) as pose:
        results = pose.process(image_rgb)

        if results.pose_landmarks:
            landmarks = results.pose_landmarks.landmark
            height, width, _ = image.shape
            tracer_points(image, landmarks, width, height)

            # Points clés nécessaires
            left_heel = landmarks[mp_pose.PoseLandmark.LEFT_HEEL]
            right_heel = landmarks[mp_pose.PoseLandmark.RIGHT_HEEL]
            left_shoulder = landmarks[mp_pose.PoseLandmark.LEFT_SHOULDER]
            right_shoulder = landmarks[mp_pose.PoseLandmark.RIGHT_SHOULDER]
            nose = landmarks[mp_pose.PoseLandmark.NOSE]

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

            # Calcul de la largeur de la taille en pixels
            edges = cv2.Canny(cv2.cvtColor(image, cv2.COLOR_BGR2GRAY), 50, 150)
            cv2.imwrite("edges_profil.png",edges)
            x_center = int(width / 2)
            x_left, x_right = x_center, x_center
            while x_left > 0 and edges[waist_y_px, x_left] == 0:
                x_left -= 1
            while x_right < width and edges[waist_y_px, x_right] == 0:
                x_right += 1

            # Conversion de la largeur de la taille en centimètres
            waist_width_px = x_right - x_left
            waist_width_cm = waist_width_px * ratio_pixel_cm

            # Annoter l'image avec les résultats
            cv2.line(image, (x_left, waist_y_px), (x_right, waist_y_px), (0, 255, 0), 3)
            cv2.putText(image, f"{waist_width_cm:.2f} cm", (x_center, waist_y_px - 20),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
            output_path = f"{image_name}_mesure_frontale.png"
            cv2.imwrite(output_path, image)

            print(f"Largeur de la taille (frontale) : {waist_width_cm:.2f} cm")
            return waist_width_cm
        else:
            print("Aucun point de repère détecté.")
            return None


import math


def calculer_bri(
    image_path_side,
    image_path_front,
    user_height_cm,
    image_name="output"
):
    """
    Calcule le Body Roundness Index (BRI) à partir de deux images :
    une vue latérale et une vue frontale.

    Paramètres
    ----------
    image_path_side : str
        Chemin vers l'image latérale.
    image_path_front : str
        Chemin vers l'image frontale.
    user_height_cm : float
        Taille réelle de la personne en centimètres.
    image_name : str
        Préfixe des images annotées.

    Retour
    ------
    dict
        Mesures, circonférence estimée et BRI.
        Retourne None si le calcul est impossible.
    """

    # 1. Vérification de la taille
    try:
        user_height_cm = float(user_height_cm)
    except (TypeError, ValueError):
        print("Erreur : la taille doit être un nombre.")
        return None

    if not math.isfinite(user_height_cm) or user_height_cm <= 0:
        print("Erreur : la taille doit être positive et finie.")
        return None

    # 2. Vérification des chemins
    if not image_path_side or not image_path_front:
        print("Erreur : les deux chemins d'images sont requis.")
        return None

    # Les fonctions de mesure renvoient les largeurs complètes, en cm.
    try:
        profondeur_laterale_cm = mesurer_profondeur_taille(
            image_path_side,
            user_height_cm,
            f"{image_name}_profil"
        )
        largeur_frontale_cm = mesurer_largeur_taille(
            image_path_front,
            user_height_cm,
            f"{image_name}_face"
        )
    except Exception as e:
        print(f"Erreur lors de la mesure : {e}")
        return None

    # 4. Validation des mesures
    if profondeur_laterale_cm is None or largeur_frontale_cm is None:
        print("Erreur : impossible de mesurer la taille.")
        return None

    try:
        profondeur_laterale_cm = float(profondeur_laterale_cm)
        largeur_frontale_cm = float(largeur_frontale_cm)
    except (TypeError, ValueError):
        print("Erreur : les mesures doivent être numériques.")
        return None

    if (
        not math.isfinite(profondeur_laterale_cm)
        or not math.isfinite(largeur_frontale_cm)
        or profondeur_laterale_cm <= 0
        or largeur_frontale_cm <= 0
    ):
        print("Erreur : mesures invalides.")
        return None

    # 5. Estimation de la circonférence par une ellipse
    # r1 et r2 sont les demi-axes, calculés à partir des largeurs complètes.
    r1 = largeur_frontale_cm / 2.0  # demi-axe frontal
    r2 = profondeur_laterale_cm / 2.0  # demi-axe latéral

    waist_circumference = 2.0 * math.pi * math.sqrt(
        (r1**2 + r2**2) / 2.0
    )

    # 6. Vérification du domaine mathématique
    ratio = waist_circumference / (
        math.pi * user_height_cm
    )

    if ratio >= 1.0:
        print(
            "Erreur : circonférence incompatible avec "
            "la taille pour cette formule."
        )
        return None

    # 7. Calcul du BRI : formule originale
    BRI = 364.2 - 365.5 * math.sqrt(
        1.0 - ratio**2
    )

    # 8. Résultats
    resultats = {
        "taille_cm": user_height_cm,
        "largeur_taille_cm": largeur_frontale_cm,
        "profondeur_taille_cm": profondeur_laterale_cm,
        "circonference_taille_cm": waist_circumference,
        "BRI": BRI
    }

    print("\n--- Résultats CircumFit ---")
    print(f"Taille : {user_height_cm:.2f} cm")
    print(f"Largeur complète de taille : {largeur_frontale_cm:.2f} cm")
    print(f"Profondeur complète de taille : {profondeur_laterale_cm:.2f} cm")
    print(
        f"Circonférence estimée : "
        f"{waist_circumference:.2f} cm"
    )
    print(f"BRI calculé : {BRI:.2f}")

    return resultats


# Exemple d'utilisation
if __name__ == "__main__":

    user_height_cm = 180

    image_path_side = r"C:\Users\elias\Downloads\demo_profil.jpg"
    image_path_front = r"C:\Users\elias\Downloads\demo_face.jpg"

    resultats = calculer_bri(
        image_path_side,
        image_path_front,
        user_height_cm
    )
