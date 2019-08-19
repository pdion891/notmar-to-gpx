# notmar-to-gpx

Generate waypoints GPX file from Canadian Coast Guard notices to mariners for marine chart updates.

Utilise le site [notmar.gc.ca](https://www.notmar.gc.ca/corrections-fr.php) pour extraire les mise-a-jour de carte marine en format gpx utilisable par OpenCPN.
Génère un ficher de waypoints en format GPX à partir des avis aux navigateurs de la Garde Cotière Canadienne pour une carte marine.

Les fichiers .gpx peuvent etre importé en couches (Layers) dans [OpenCPN](https://opencpn.org/) .

## known issues

- Does not import sector or move of objects.

## how to use

Require [Ruby](https://www.ruby-lang.org/en/)

  bundle install
  ./notmar-to-gpx.rb --start-date=2011-01-01 1221
