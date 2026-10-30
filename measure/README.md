Cette API calcule la circonférence de la taille et l'indice de rondeur corporelle (BRI) à partir de deux images (vue frontale et vue latérale) et de la taille de l'utilisateur. Elle est déployée sur un serveur accessible publiquement.

Pour calculer le BRI, `/calculate-bri` reçoit les photos ainsi que les champs
`patient_id` (pseudonyme accepté), `sex` (`Male` ou `Female`), `age`,
`weight_kg` et `user_height_cm` (de 100 à 230 cm). L'identifiant, le sexe,
l'âge et le poids sont transmis et validés, mais ne sont ni enregistrés ni
utilisés dans la formule actuelle du BRI.

L'API est déployée sur : https://circumfit.onrender.com
endpoint (/calculate-bri) : https://circumfit.onrender.com/calculate-bri
 
Erreur 405 - Method Not Allowed :

    Vérifiez que vous utilisez bien une requête POST au lieu de GET.

Erreur 404 - Not Found :

    Vérifiez l'URL de l'endpoint.
    Assurez-vous que le serveur est actif.

Le fichier app.py est l'API utilisé pour l'application (relié à l'interface et déploier en ligne).

Le fichier measure_final.py est pour tester et améliorer l'algorithme de mesure individuellement. C'est un fichier python indépendant que vous pouvez runner en indiquant les chemins des photos et en changeant la taille du sujet. Les modifications finales devront esnuite être ajoutées sur app.py.

Les fichiers requirements.txt et Procfile sont utilisés pour le déploiement en ligne de l'algorithme (cf rapport).

### Largeurs mesurées et demi-axes de l'ellipse

Les fonctions de mesure renvoient des **largeurs complètes** en centimètres :
`largeur_taille_cm` correspond à la largeur frontale et `profondeur_taille_cm`
à la profondeur latérale. Ce ne sont pas des demi-axes.

Pour estimer la circonférence avec l'approximation elliptique, le code convertit
ces largeurs en demi-axes :

- `r₁ = largeur_taille_cm / 2` : demi-axe frontal ;
- `r₂ = profondeur_taille_cm / 2` : demi-axe latéral.

La circonférence estimée est `2π × √((r₁² + r₂²) / 2)`. Ainsi, les valeurs
affichées comme largeur et profondeur restent les dimensions complètes mesurées ;
seuls `r₁` et `r₂` sont les demi-axes utilisés dans cette formule.

### Segmentation de la silhouette (A-04)

Les bords de la silhouette sur la ligne de mesure sont trouvés en priorité
avec le **masque de segmentation** de MediaPipe Pose (`enable_segmentation=True`,
modèle déjà embarqué, aucune dépendance ajoutée). La largeur retenue est celle
du segment « personne » qui contient le milieu des hanches : les bras écartés,
les motifs des vêtements, les ombres et le décor ne coupent plus la mesure.

**Canny reste en repli** si le masque est absent, quasi vide, couvre presque
toute l'image, ou si le segment obtenu touche le bord de l'image ou a une
largeur aberrante. Si aucune méthode n'aboutit, la mesure renvoie `None`
(au lieu d'une largeur égale à toute l'image comme en V2).

L'API renvoie la méthode utilisée pour chaque vue :

```json
"segmentation": {
  "face":   {"methode": "masque", "raison_repli": null},
  "profil": {"methode": "canny",  "raison_repli": "masque absent"}
}
```

Le code est dans `segmentation.py` (fonctions pures). Tests :
`python -m pytest measure -q` depuis la racine du dépôt.

Limite connue : si les bras touchent le tronc au niveau de la ligne de mesure,
le masque les inclut. Le protocole de pose (F-10) et le contrôle qualité (F-14)
doivent l'éviter.
