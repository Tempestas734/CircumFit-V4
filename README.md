# circumfit_v3

CircumFit est une application mobile  développée dans le cadre d’un projet de fin d'études. Cette application est conçue pour mesurer le tour de taille et calculer le BRI d'un individu.

Dossier lib (Contient les fichiers principaux relatifs aux différentes pages de ) :
    - main.dart : Page d’accueil de l’application.
    - check_detail_page.dart : Page de saisie des informations personnelles (comme la taille).
    - face_profile_photos_page.dart : Page permettant de sélectionner les photos de face et de profil.
    - historique_page.dart : Page historique (à implémenter pour suivre les mesures).
    - about_page.dart : Page d’informations sur l’application.

Dossier measure : app.py et measure_final_.py :API et code Python permettant de calculer le tour de taille. (voir README respectif).

Dossier assets : illustrations et icônes utilisées dans l'application.

Sur iOS et Android, l'écran caméra utilise `assets/posenet.tflite` pour repérer
les épaules, les poignets et les chevilles en direct. La photo est activée
lorsque ces repères sont visibles dans la silhouette. Le flux caméra web ne
permettant pas cette analyse dans le plugin actuel, le navigateur conserve un
cadrage manuel. Le réglage de luminosité est toujours affiché : il utilise
l'exposition matérielle quand elle est disponible, et ajuste l'aperçu ainsi que
la photo enregistrée sinon. Le niveau du téléphone affiche l'angle si un
accéléromètre est accessible; à défaut, l'écran indique que l'alignement doit
être vérifié manuellement.

Le même modèle produit aussi un masque de personne basse résolution
(`float_segments`, 17 × 23), calculé localement et affiché en surimpression
verte dans le guide. À la capture, ML Kit segmente également chaque image
localement avec un masque haute résolution ; les repères de pose en direct
servent à choisir la ligne de taille et à convertir sa largeur en centimètres.
Les largeurs face/profil sont combinées avec l'approximation de Ramanujan II
pour calculer une circonférence et un BRI local. Le facteur de forme est fixé
à 1.0 faute de mesures de référence : le résultat est expérimental et ne
constitue pas une mesure clinique.

Pendant cette phase de comparaison, les deux photos sont aussi envoyées à
l'API, qui continue d'utiliser MediaPipe.
L'écran de résultats affiche côte à côte les valeurs serveur et locales ; une
erreur de mesure locale est indiquée sans remplacer le résultat local par la
valeur serveur. La segmentation sur appareil nécessite iOS 15.5 ou supérieur
sur iPhone (Android reste pris en charge à partir du minimum du projet).

Autres dossiers importants

    - build/ : Dossier généré automatiquement contenant les fichiers nécessaires pour la compilation de l’application.
    - test/ : Contient des fichiers de test pour vérifier le bon fonctionnement des différentes fonctionnalités.
    - android/ et ios/ : Dossiers spécifiques aux configurations et déploiements sur les plateformes Android et iOS.

Exécution : Lancer l’application sur un émulateur ou un appareil connecté via Flutter (pour cela, il faut configurer son téléphone en mode développeur https://developer.android.com/studio/debug/dev-options?hl=fr et utiliser un cable usb connecté à l'ordinateur et le smartphone).