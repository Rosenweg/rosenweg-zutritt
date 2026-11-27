#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Logo "Rosenweg Zutritt" aus dem Logo-Baukasten von rosenweg-basis: Wappen
# (Turm, Weg, Rose) und rechts unten die Plakette mit dem Zeichen der App
# (assets/logo/zeichen/zutritt.svg), Farbe des Zeichens nach Zielgruppe.
# Schreibt alle Symbole: Android (adaptive, monochrom), iOS, macOS (+ .icns),
# Windows (.ico), Linux (SVG; die hicolor-PNGs rechnet linux/paket/bauen.sh),
# /apps (assets/logo/rosenweg-zutritt-192.png) und den DMG-Hintergrund.
# Aufruf aus dem Repo-Wurzelverzeichnis:
#   sh assets/logo/erzeugen.sh [pfad/zu/rosenweg-basis]
set -eu
BASIS="${1:-../rosenweg-basis}"
GRUPPE=technik
sh "$BASIS/werkzeug/logo/app-symbole.sh" . rosenweg-zutritt "Rosenweg Zutritt" assets/logo/zeichen/zutritt.svg "$GRUPPE"
