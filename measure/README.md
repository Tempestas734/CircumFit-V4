Cette API calcule la circonférence de la taille et l'indice de rondeur corporelle (BRI) à partir de deux images (vue frontale et vue latérale) et de la taille de l'utilisateur. Elle est déployée sur un serveur accessible publiquement.

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