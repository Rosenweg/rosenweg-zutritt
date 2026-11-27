#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Baut die ausgelieferte macOS-App und das DMG. Aus der App-Vorlage von
# rosenweg-basis (Muster: rosenweg-salz, rosenweg-vm macos/installer/bauen.sh
# ohne dessen native Bibliotheken: nichts zu buendeln, die App ist universal
# arm64 + x86_64).
#
#   macos/installer/bauen.sh [--ohne-flutter] [--ohne-dmg]
#
# Ergebnis in build/macos-installer/:
#   Rosenweg Zutritt.app              signiert (Developer ID oder ad hoc)
#   Rosenweg-Zutritt-<version>.dmg    Installer (Hintergrund, Programme-Verknuepfung)
#
# Umgebung (alles optional, wie rosenweg-vm):
#   RW_SIGNIER_ID     codesign-Identitaet; leer = erste "Developer ID
#                     Application" im Schluesselbund, sonst "-" (ad hoc)
#   RW_NOTAR_PROFIL   notarytool-Schluesselbundprofil; Standard rosenweg-notar
#   RW_NOTAR_KEY, RW_NOTAR_KEY_ID, RW_NOTAR_ISSUER
#                     statt Profil: App-Store-Connect-API-Schluessel (CI)
#
# Laeuft mit dem bash 3.2 von macOS.
set -euo pipefail

WURZEL="$(cd "$(dirname "$0")/../.." && pwd)"
HIER="$WURZEL/macos/installer"
AUS="$WURZEL/build/macos-installer"
NAME="Rosenweg Zutritt"
DATEINAME="Rosenweg-Zutritt"

FLUTTER=1 DMG=1
for a in "$@"; do
    case "$a" in
    --ohne-flutter) FLUTTER=0 ;;
    --ohne-dmg) DMG=0 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "Unbekannte Option: $a" >&2; exit 2 ;;
    esac
done

schritt() { printf '\n== %s\n' "$*"; }
fehler() { echo "FEHLER: $*" >&2; exit 1; }

cd "$WURZEL"
VERSION="$(sed -n 's/^version: *\([0-9.]*\)+\{0,1\}\([0-9]*\).*/\1/p' pubspec.yaml)"
[ -n "$VERSION" ] || fehler "Version aus pubspec.yaml nicht lesbar"

if [ "$FLUTTER" = 1 ]; then
    schritt "flutter build macos --release"
    flutter build macos --release
fi
QUELLE="build/macos/Build/Products/Release/$NAME.app"
[ -d "$QUELLE" ] || fehler "$QUELLE fehlt"

schritt "Buendel"
rm -rf "$AUS"
mkdir -p "$AUS"
APP="$AUS/$NAME.app"
ditto "$QUELLE" "$APP"
LIZ="$APP/Contents/Resources/Lizenzen"
mkdir -p "$LIZ"
cp LICENSE "$LIZ/"
PROGRAMM="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist")"
echo "Architektur: $(lipo -archs "$APP/Contents/MacOS/$PROGRAMM")"

schritt "Signieren"
if [ -z "${RW_SIGNIER_ID:-}" ]; then
    RW_SIGNIER_ID="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -n1)"
    RW_SIGNIER_ID="${RW_SIGNIER_ID:--}"
fi
ENT="$WURZEL/macos/Runner/Release.entitlements"
if [ "$RW_SIGNIER_ID" = "-" ]; then
    echo "keine Developer-ID-Identitaet: ad hoc (Gatekeeper fragt beim ersten Start)"
    SIG=(--force --sign - --timestamp=none)
else
    echo "Identitaet: $RW_SIGNIER_ID (Hardened Runtime)"
    SIG=(--force --sign "$RW_SIGNIER_ID" --timestamp --options runtime)
fi
signieren() { codesign "${SIG[@]}" "$@" 2>&1 | grep -v "replacing existing signature" || true; }
for f in "$APP/Contents/Frameworks"/*.framework "$APP/Contents/Frameworks"/*.dylib; do
    [ -e "$f" ] && signieren "$f"
done
signieren --entitlements "$ENT" "$APP"
codesign --verify --deep --strict --verbose=1 "$APP"

[ "$DMG" = 1 ] || { echo "fertig: $APP"; exit 0; }

schritt "DMG"
VENV="$WURZEL/build/dmgbuild-venv"
if [ ! -x "$VENV/bin/dmgbuild" ]; then
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install -q --disable-pip-version-check "dmgbuild==1.6.7"
fi
tiffutil -cathidpicheck "$HIER/hintergrund.png" "$HIER/hintergrund@2x.png" -out "$AUS/hintergrund.tiff" >/dev/null
SYMBOL="$APP/Contents/Resources/AppIcon.icns"
[ -f "$SYMBOL" ] || fehler "$SYMBOL fehlt"
DMG_DATEI="$AUS/$DATEINAME-$VERSION.dmg"
"$VENV/bin/dmgbuild" -s "$HIER/dmg-einstellungen.py" \
    -D app="$APP" -D hintergrund="$AUS/hintergrund.tiff" -D symbol="$SYMBOL" \
    "$NAME" "$DMG_DATEI"

if [ "$RW_SIGNIER_ID" != "-" ]; then
    codesign --force --sign "$RW_SIGNIER_ID" --timestamp "$DMG_DATEI"
    NOTAR=()
    if [ -n "${RW_NOTAR_KEY:-}" ] && [ -n "${RW_NOTAR_KEY_ID:-}" ] && [ -n "${RW_NOTAR_ISSUER:-}" ]; then
        NOTAR=(--key "$RW_NOTAR_KEY" --key-id "$RW_NOTAR_KEY_ID" --issuer "$RW_NOTAR_ISSUER")
    else
        P="${RW_NOTAR_PROFIL:-rosenweg-notar}"
        if xcrun notarytool history --keychain-profile "$P" >/dev/null 2>&1; then
            NOTAR=(--keychain-profile "$P")
        fi
    fi
    if [ ${#NOTAR[@]} -gt 0 ]; then
        schritt "Notarisieren (dauert einige Minuten)"
        xcrun notarytool submit "$DMG_DATEI" "${NOTAR[@]}" --wait
        xcrun stapler staple "$DMG_DATEI"
        spctl --assess --type open --context context:primary-signature --verbose "$DMG_DATEI"
    else
        echo "kein notarytool-Profil: DMG signiert, aber nicht notarisiert"
    fi
fi
echo
echo "fertig: $DMG_DATEI"
