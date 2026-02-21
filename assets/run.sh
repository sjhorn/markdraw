#!/bin/bash

rm markdraw.png
./svg2appiconset.sh markdraw.svg
mv AppIcon.appiconset/icon_mac512.png ./markdraw.png
rm -Rf AppIcon.appiconset
./clear_icon_cache.sh
cd ..
flutter clean && flutter pub get
cd assets