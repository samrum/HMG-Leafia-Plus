#!/bin/sh
# Rebuild patches/<set>/Iap2ServerApp.bridge.lpd from the upstream bridge build
# plus src/iap2/ev_engine.py (iAP2 identification says EngineType Electric).
# Needs the car's stock Iap2ServerApp.odex (Leafia keeps it in
# /data/nemesis/backup/projection.tbt/ on the unit), python3 with
# tools/requirements.txt, and the host lpatch (tools/lpatch/build.sh).
#
# usage: src/iap2/rebuild.sh <set> <stock Iap2ServerApp.odex> [--check]
#   --check  only compare the result with the committed .lpd
set -e
BASE_REF=${BASE_REF:-5673ee0}
SET=$1 ODEX=$2 CHECK=$3
[ -n "$SET" ] && [ -f "$ODEX" ] || { sed -n '2,9p' "$0"; exit 1; }
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
LP="$ROOT/tools/lpatch/lpatch-host"
[ -x "$LP" ] || { echo "build tools/lpatch/lpatch-host first (tools/lpatch/build.sh)"; exit 1; }
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
git -C "$ROOT" show "$BASE_REF:patches/$SET/Iap2ServerApp.bridge.lpd" > "$W/base.lpd"
"$LP" delta "$W/base.lpd" "$ODEX" "$W/base.dex" > /dev/null
# TEST ONLY: --mock-status sends fixed range/temperature values (not the car's).
# Drop it before this goes to main.
python3 -I "$HERE/ev_engine.py" "$W/base.dex" "$W/classes.dex" --mock-status
OUT="$ROOT/patches/$SET/Iap2ServerApp.bridge.lpd"
got=$(md5sum < "$W/classes.dex" | cut -d' ' -f1)
if [ "$CHECK" = --check ]; then
    want=$(dd if="$OUT" bs=1 skip=28 count=16 2>/dev/null | od -An -tx1 | tr -d ' \n')
    [ "$want" = "$got" ] && echo "OK: source rebuilds patches/$SET/Iap2ServerApp.bridge.lpd ($got)" \
        || { echo "MISMATCH: committed $want, source gives $got"; exit 1; }
else
    python3 "$ROOT/tools/mkdelta.py" "$ODEX" "$W/classes.dex" "$OUT"
    echo "classes.dex md5 $got; now update the 3_bridge Iap2ServerApp md5 in patches/$SET/manifest and run tools/compat-built.py"
fi
