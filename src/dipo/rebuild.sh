#!/bin/sh
# Rebuild patches/<set>/HKMC_DiPO.bridge.lpd from the Leafia bridge build plus
# the source in src/dipo. Needs the car's stock HKMC_DiPO.odex (Leafia keeps it
# in /data/nemesis/backup/projection.tbt/ on the unit), java, python3 with
# tools/requirements.txt, and the host lpatch (tools/lpatch/build.sh).
#
# usage: src/dipo/rebuild.sh <set> <stock HKMC_DiPO.odex> [--check]
#   --check  build into a temp folder and only compare with the committed .lpd
#
# The base is the upstream bridge patch at BASE_REF (git), rebuilt with
# `lpatch delta`. It is disassembled, src/dipo/smali is copied in, hooks.py
# adds the calls for FEATURES, and the result is reassembled and diffed
# against the stock odex with tools/mkdelta.py. smali/baksmali 2.5.2 are
# downloaded once into src/dipo/.tools (git-ignored) and checked by sha256.
# Both run with -j 1: smali with several threads lays the dex out differently
# on every run, and the .lpd must be reproducible.
set -e
BASE_REF=${BASE_REF:-08f4436}
FEATURES="hid-home-back auto-open auto-open-home mute call-key favorite-home"
SET=$1 ODEX=$2 CHECK=$3
[ -n "$SET" ] && [ -f "$ODEX" ] || { sed -n '2,13p' "$0"; exit 1; }
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
T="$HERE/.tools"
mkdir -p "$T"
fetch() {
    [ -f "$T/$1" ] || curl -sSfL -o "$T/$1" "https://bitbucket.org/JesusFreke/smali/downloads/$1"
    echo "$2  $T/$1" | sha256sum -c --quiet - || { rm -f "$T/$1"; exit 1; }
}
fetch baksmali-2.5.2.jar d3116248cce4f82ec5a31eb7f95ee75daff42ddf6eed0ab573973dc53fbad2e5
fetch smali-2.5.2.jar 9544299578b16f771d8aa8eaefe0d3718ca03478c16f3c356f2fcf1366bfb116
LP="$ROOT/tools/lpatch/lpatch-host"
[ -x "$LP" ] || { echo "build tools/lpatch/lpatch-host first (tools/lpatch/build.sh)"; exit 1; }

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
git -C "$ROOT" show "$BASE_REF:patches/$SET/HKMC_DiPO.bridge.lpd" > "$W/base.lpd"
"$LP" delta "$W/base.lpd" "$ODEX" "$W/base.dex" > /dev/null
java -jar "$T/baksmali-2.5.2.jar" d -a 18 -j 1 "$W/base.dex" -o "$W/smali"
cp -R "$HERE/smali/." "$W/smali/"
python3 "$HERE/hooks.py" "$W/smali" $FEATURES
java -jar "$T/smali-2.5.2.jar" a -a 18 -j 1 "$W/smali" -o "$W/classes.dex"
OUT="$ROOT/patches/$SET/HKMC_DiPO.bridge.lpd"
if [ "$CHECK" = --check ]; then
    python3 "$ROOT/tools/mkdelta.py" "$ODEX" "$W/classes.dex" "$W/new.lpd" > /dev/null
    # bytes 28..44 of an .lpd: md5 of the target
    want=$(dd if="$OUT" bs=1 skip=28 count=16 2>/dev/null | od -An -tx1 | tr -d ' \n')
    got=$(md5sum < "$W/classes.dex" | cut -d' ' -f1)
    [ "$want" = "$got" ] && echo "OK: source rebuilds patches/$SET/HKMC_DiPO.bridge.lpd ($got)" \
        || { echo "MISMATCH: committed $want, source gives $got"; exit 1; }
else
    python3 "$ROOT/tools/mkdelta.py" "$ODEX" "$W/classes.dex" "$OUT"
    echo "now update the 3_bridge HKMC_DiPO md5 in patches/$SET/manifest and run tools/compat-built.py"
fi
