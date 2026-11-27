# Einstellungen fuer dmgbuild (https://dmgbuild.readthedocs.io).
# Aufruf aus bauen.sh:
#   dmgbuild -s dmg-einstellungen.py -D app=<.app> -D hintergrund=<.tiff> \
#            -D symbol=<.icns> "Rosenweg Zutritt" <ziel.dmg>
# dmgbuild schreibt das Finder-Layout (.DS_Store) selbst; kein Finder, kein
# AppleScript noetig, darum laeuft es auch auf einem CI-Runner ohne Sitzung.
import os.path

app = defines["app"]  # noqa: F821 (von dmgbuild gesetzt)
app_name = os.path.basename(app)

format = "UDZO"  # zlib, auf jedem macOS lesbar
filesystem = "HFS+"
size = None  # aus dem Inhalt berechnet

files = [app]
symlinks = {"Programme": "/Applications"}
# Volume-Symbol = App-Symbol
icon = defines["symbol"]  # noqa: F821
badge_icon = None

background = defines["hintergrund"]  # noqa: F821 (TIFF mit 1x und 2x)
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
default_view = "icon-view"
show_icon_preview = False
include_icon_view_settings = True
include_list_view_settings = False

# Fenster passend zum Hintergrund (640x420 Inhalt). Die Hoehe zaehlt die
# Titelleiste mit (macOS 26/27: ca. 32 pt), sonst fehlt unten die Fusszeile.
window_rect = ((200, 160), (640, 452))
arrange_by = None
grid_spacing = 100
label_pos = "bottom"
text_size = 13
icon_size = 112
# Mitte der Symbole, passend zum Pfeil in hintergrund.svg
icon_locations = {
    app_name: (165, 215),
    "Programme": (475, 215),
}
hide_extension = [app_name]
