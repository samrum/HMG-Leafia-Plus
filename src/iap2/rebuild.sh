#!/bin/sh
# Rebuild the EV test patches for one car set:
#   patches/<set>/Iap2ServerApp.bridge.lpd  upstream bridge build + ev_engine.py
#   patches/<set>/libiap2session.ev.lpd     evnative/ev_native.py on the stock library
# Needs the car's stock Iap2ServerApp.odex and lib/libiap2session.so (Leafia
# keeps the odex in /data/nemesis/backup/projection.tbt/ on the unit; a port
# kit has both), python3 with tools/requirements.txt, binutils for ARM
# (binutils-arm-linux-gnueabi) and the host lpatch (tools/lpatch/build.sh).
#
# usage: src/iap2/rebuild.sh <set> <stock Iap2ServerApp.odex> <stock libiap2session.so> [--check]
#   --check  only compare the results with the committed .lpd files
set -e
BASE_REF=${BASE_REF:-5673ee0}
SET=$1 ODEX=$2 LIB=$3 CHECK=$4
[ -n "$SET" ] && [ -f "$ODEX" ] && [ -f "$LIB" ] || { sed -n '2,11p' "$0"; exit 1; }
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
LP="$ROOT/tools/lpatch/lpatch-host"
[ -x "$LP" ] || { echo "build tools/lpatch/lpatch-host first (tools/lpatch/build.sh)"; exit 1; }
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
git -C "$ROOT" show "$BASE_REF:patches/$SET/Iap2ServerApp.bridge.lpd" > "$W/base.lpd"
"$LP" delta "$W/base.lpd" "$ODEX" "$W/base.dex" > /dev/null
# TEST ONLY (both): fixed EV values, not the car's. Not for main as it is.
python3 -I "$HERE/ev_engine.py" "$W/base.dex" "$W/classes.dex" --ev-status
python3 -I "$HERE/evnative/ev_native.py" "$LIB" "$W/libiap2session.so"

# one <stock> <result> <lpd>
one() {
    got=$(md5sum < "$2" | cut -d' ' -f1)
    if [ "$CHECK" = --check ]; then
        want=$(dd if="$3" bs=1 skip=28 count=16 2>/dev/null | od -An -tx1 | tr -d ' \n')
        [ "$want" = "$got" ] && echo "OK: source rebuilds ${3#$ROOT/} ($got)" \
            || { echo "MISMATCH: ${3#$ROOT/} committed $want, source gives $got"; exit 1; }
    else
        python3 "$ROOT/tools/mkdelta.py" "$1" "$2" "$3"
        echo "${3#$ROOT/}: result md5 $got"
    fi
}
one "$ODEX" "$W/classes.dex" "$ROOT/patches/$SET/Iap2ServerApp.bridge.lpd"
one "$LIB" "$W/libiap2session.so" "$ROOT/patches/$SET/libiap2session.ev.lpd"
if [ "$CHECK" != --check ]; then
    "$LP" zipadd "$(dirname "$ODEX")/Iap2ServerApp.apk" "$W/classes.dex" "$W/Iap2ServerApp.apk" > /dev/null 2>&1 \
        && echo "Iap2ServerApp.apk md5 $(md5sum < "$W/Iap2ServerApp.apk" | cut -d' ' -f1)"
    echo "now update the 3_bridge lines in patches/$SET/manifest (APK md5 for Iap2ServerApp,"
    echo "library md5 for libiap2session.so) and run tools/compat-built.py"
fi
