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

### Circonférence elliptique et facteur de forme

Les fonctions de mesure renvoient des **largeurs complètes** en centimètres :
`largeur_taille_cm` correspond à la largeur frontale et `profondeur_taille_cm`
à la profondeur latérale. Ce ne sont pas des demi-axes.

Le calcul distingue les largeurs complètes des demi-axes :
`r1 = largeur_taille_cm / 2` et `r2 = profondeur_taille_cm / 2`, puis applique
l'approximation de Ramanujan II :

`π × (r1 + r2) × [1 + 3h / (10 + √(4 − 3h))]`, où
`h = ((r1 − r2) / (r1 + r2))²`.

Le résultat est multiplié par un facteur de forme. Il vaut actuellement **1,0
(non calibré)**, car aucun jeu de mesures de référence au mètre ruban n'est
disponible dans le dépôt. La fonction `calibrate_waist_shape_factor` de
`circumference.py` permet de l'ajuster par moindres carrés à partir de mesures
frontales, latérales et de circonférences de référence ; la valeur retournée
doit ensuite remplacer `DEFAULT_WAIST_SHAPE_FACTOR`. Tant que ce facteur n'a
pas été calculé sur des données de référence, les résultats ne doivent pas être
présentés comme calibrés.

Le BRI suit l'équation de Thomas et al. :
`364,2 − 365,5 × √(1 − [circonférence / (π × taille)]²)`.
Le rapport est mis au carré puis passé sous une racine carrée ; il ne faut pas
utiliser une puissance 2,5. Cette formule est partagée entre l'API, le script
autonome et le calcul local dans l'application, avec des tests dédiés.

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

### Mesure multi-lignes avec médiane (F-23)

La largeur (vue de face) et la profondeur (vue de profil) ne sont plus lues sur
une seule ligne : elles sont mesurées sur **9 lignes** régulièrement réparties
dans une bande de **± 2 % de la hauteur du sujet** autour du niveau retenu, et
la valeur gardée est la **médiane** des lignes valides. Un bord mal détecté sur
quelques lignes (bras qui touche le tronc localement, ombre, pli de vêtement)
n'influence donc plus le résultat.

- Chaque ligne est mesurée comme en A-04 (masque, Canny en repli). Le masque
  est préparé une seule fois pour toutes les lignes : pas de surcoût de calcul.
- Si moins de la moitié des lignes sont valides, la mesure est refusée (`None`)
  plutôt que calculée sur une ou deux lignes.
- La bande est exprimée en fraction de la hauteur du sujet en pixels : le
  résultat ne dépend pas de la résolution de la photo.
- Paramètres (`N_LIGNES`, `DEMI_BANDE_FRACTION`, `FRACTION_LIGNES_VALIDES_MIN`
  dans `segmentation.py`) choisis sans calibration, à revoir avec la campagne
  de mesures (E-06).

L'API renvoie en plus, pour chaque vue, le détail des lignes. `methode` vaut
`mixte` si certaines lignes ont été mesurées par le masque et d'autres par Canny ;
un `ecart_px` élevé signale des bords incohérents d'une ligne à l'autre.

```json
"face": {
  "methode": "masque", "raison_repli": null,
  "lignes": {"n_valides": 9, "n_total": 9, "ecart_px": 4,
             "demi_bande_px": 60, "par_methode": {"masque": 9, "canny": 0}}
}
```

Tests : `measure/test_multilignes.py` (masques synthétiques, sans photo).

Limite : si les bras touchent le tronc sur toute la hauteur de la bande, la
médiane ne peut pas les écarter ; le protocole de pose (F-10) reste nécessaire.
