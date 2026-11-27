#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# ============================================================================
# linux/paket/im-container.sh — das Paket im Bau-Container bauen
# ============================================================================
#   linux/paket/im-container.sh [knoten] [ct] [basis-ordner]
#   RW_BAU_KNOTEN=root@<knoten> linux/paket/im-container.sh                 (Knoten aus der Umgebung)
#   linux/paket/im-container.sh root@<knoten> 141 ../rosenweg-basis
#
#   Fuer den Proxmox-Knoten mit dem Bau-Container gibt es keine Vorgabe (oeffentl.
#   Repo): als erstes Argument oder in RW_BAU_KNOTEN (z. B. in ~/.profile);
#   der Container in RW_BAU_CT oder als zweites Argument (Vorgabe 141).
#
# Muster: rosenweg-profil und rosenweg-vm. Der Bau-Container (CT 141,
# Debian 13) hat keinen Zugang zu GitHub; der Quellstand geht als Archiv ueber
# den Knoten hinein ('pct push'), das .deb auf demselben Weg zurueck.
#
# Mitgeschickt wird der Arbeitsstand von rosenweg-zutritt, auch Ungespeichertes
# (eigener Index, .gitignore gilt; im Paket steht dann '+geaendert'). Von
# rosenweg-basis (im Container ist GitHub nicht erreichbar) geht genau die
# Fassung mit, die pubspec.yaml nennt (git: ref: v0.2.0), aus dem
# Nachbarordner — nicht dessen Arbeitsstand. Wer gegen den Arbeitsstand der
# Basis bauen will: RW_BASIS_ARBEITSSTAND=1.
#
# Gebaut wird unter /root/bau/rosenweg-zutritt/ (eigener Ordner, damit ein Bau von
# rosenweg-profil mit seinem /root/bau/rosenweg-basis nicht kollidiert).
# Flutter und der Pub-Cache liegen im gemeinsamen Cache von rosenweg-vm.
# Laeuft schon ein Flutter-Bau im Container, bricht das Skript ab.
# ============================================================================
# shellcheck disable=SC2029
set -euo pipefail

KNOTEN="${1:-${RW_BAU_KNOTEN:-}}"
CTID="${2:-${RW_BAU_CT:-141}}"
[ -n "$KNOTEN" ] || { echo "FEHLER: Knoten fehlt - als erstes Argument (root@<knoten>) oder in RW_BAU_KNOTEN." >&2; exit 2; }
HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WURZEL="$(cd "$HIER/../.." && pwd)"
BASIS="$(cd "${3:-$WURZEL/../rosenweg-basis}" && pwd)"
cd "$WURZEL"

arbeitsstand() { # <repo> <datei> -> Stand
    local repo="$1" ziel="$2" index baum stand
    stand="$(git -C "$repo" rev-parse --short=12 HEAD)"
    index="$(mktemp "${TMPDIR:-/tmp}/rw-index.XXXXXX")"
    cp "$(git -C "$repo" rev-parse --git-path index)" "$index" 2>/dev/null || rm -f "$index"
    baum="$(cd "$repo" && GIT_INDEX_FILE="$index" git add -A && GIT_INDEX_FILE="$index" git write-tree)"
    rm -f "$index"
    [ "$baum" = "$(git -C "$repo" rev-parse 'HEAD^{tree}')" ] || stand="$stand+geaendert"
    git -C "$repo" archive --format=tar.gz -o "$ziel" "$baum"
    echo "$stand"
}

T="$(mktemp -d "${TMPDIR:-/tmp}/rw-app.XXXXXX")"
trap 'rm -rf "$T"' EXIT
STAND="$(arbeitsstand "$WURZEL" "$T/app.tar.gz")"
if [ "${RW_BASIS_ARBEITSSTAND:-0}" = 1 ]; then
    BSTAND="$(arbeitsstand "$BASIS" "$T/basis.tar.gz")"
else
    REF="$(sed -n '/rosenweg-basis.git/,/ref:/s/^[[:space:]]*ref:[[:space:]]*\([^[:space:]]*\).*/\1/p' pubspec.yaml)"
    [ -n "$REF" ] || { echo "FEHLER: ref der Basis nicht in pubspec.yaml" >&2; exit 1; }
    git -C "$BASIS" rev-parse -q --verify "$REF^{commit}" >/dev/null || git -C "$BASIS" fetch -q --tags origin
    git -C "$BASIS" archive --format=tar.gz -o "$T/basis.tar.gz" "$REF"
    BSTAND="$REF"
fi
EPOCH="$(git log -1 --format=%ct)"

if ssh "$KNOTEN" "pct exec $CTID -- pgrep -f flutter" >/dev/null; then
    echo "FEHLER: im CT $CTID laeuft schon ein Flutter-Bau (pgrep -f flutter) — spaeter nochmals." >&2
    exit 1
fi

B=/root/bau/rosenweg-zutritt
ZW="/tmp/rosenweg-zutritt-bau.$$"
ssh "$KNOTEN" "rm -rf $ZW && mkdir -p $ZW"
scp -q "$T/app.tar.gz" "$T/basis.tar.gz" "$KNOTEN:$ZW/"
ssh "$KNOTEN" "pct exec $CTID -- rm -rf $B \
    && pct exec $CTID -- mkdir -p $B/rosenweg-zutritt $B/rosenweg-basis \
    && pct push $CTID $ZW/app.tar.gz $B/app.tar.gz \
    && pct push $CTID $ZW/basis.tar.gz $B/basis.tar.gz \
    && pct exec $CTID -- tar -xzf $B/app.tar.gz -C $B/rosenweg-zutritt \
    && pct exec $CTID -- tar -xzf $B/basis.tar.gz -C $B/rosenweg-basis \
    && pct exec $CTID -- sh -c 'printf \"dependency_overrides:\\n  rosenweg_basis:\\n    path: ../rosenweg-basis\\n\" > $B/rosenweg-zutritt/pubspec_overrides.yaml' \
    && pct exec $CTID -- env RW_STAND=$STAND.basis-$BSTAND SOURCE_DATE_EPOCH=$EPOCH \
         bash $B/rosenweg-zutritt/linux/paket/bauen.sh"

DATEI="$(ssh "$KNOTEN" "pct exec $CTID -- cat $B/rosenweg-zutritt/linux/paket/out/DATEI")"
mkdir -p "$HIER/out"
ssh "$KNOTEN" "pct pull $CTID $B/rosenweg-zutritt/linux/paket/out/$DATEI $ZW/$DATEI"
scp -q "$KNOTEN:$ZW/$DATEI" "$HIER/out/$DATEI"
ssh "$KNOTEN" "rm -rf $ZW"

echo
echo "Zurückgeholt: $HIER/out/$DATEI"
cd "$HIER/out"
shasum -a 256 "$DATEI" 2>/dev/null || sha256sum "$DATEI"
