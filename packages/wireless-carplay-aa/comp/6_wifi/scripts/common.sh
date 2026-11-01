#!/system/bin/sh
# wifi.client - the stock Wi-Fi settings screen (HKMC_WifiSettings) with the opt-in Wi-Fi
# client (LEAFIA-WIFI-CLIENT, part 1). The unit's one radio runs either the hotspot that
# wireless CarPlay/AA use or the Wi-Fi client. Stock, opening the Wi-Fi screen stopped the
# projection hotspot (CarPlay dropped), turning Wi-Fi on while it ran ended in "Error" with
# Wi-Fi and the hotspot dead until a restart, turning Wi-Fi off never brought the hotspot
# back, and the Wi-Fi tab was labelled "Wi-Fi Hotspot". This installs a HKMC_WifiSettings
# rebuilt on the unit (scripts/build.sh, patches/common/optional, tools/mkwifi.py) that keeps
# the hotspot when the screen opens, waits for it to stop before starting the client, brings
# it back when the client goes off (or fails), and labels the tab "Wi-Fi".
# Only when the Wi-Fi screen can be reached (the android.hardware.wifi feature is on: from
# the opt-in, or part 1 adding it where the firmware removes the hotspot, as on the US
# Ioniq 5) and only when this unit's HKMC_WifiSettings is the stock file the fix is for;
# otherwise this part does nothing. Uninstall writes the snapshot back.

export PATH=/data/nemesis/bin:/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
export LD_LIBRARY_PATH=/vendor/lib:/system/lib

BACKUP_DIR=/data/nemesis/backup/wifi.client
LOG=/data/nemesis/wifi.client.log
APP=HKMC_WifiSettings
LIVE_APK=/system/app/$APP.apk
LIVE_ODEX=/system/app/$APP.odex
NEW_APK=/data/nemesis/build/wireless.carplay.aa/6_wifi/$APP.apk
# part 1 (wireless.projection) records here that it turned the Wi-Fi client on
WIFI_CLIENT_FLAG=/data/nemesis/backup/wireless.projection/wifi_client
# the Android Wi-Fi feature: with it the Data/Network screen shows the Wi-Fi tab. Part 1 also
# adds it without the opt-in where the firmware removes the hotspot feature (US Ioniq 5),
# so the screen (and the stock bugs) are there either way. Part 1 runs before this part.
WIFI_FEATURE=/system/etc/permissions/android.hardware.wifi.xml

wifi_client_on() { [ -f "$WIFI_CLIENT_FLAG" ] || [ -f "$WIFI_FEATURE" ]; }

log() {
    echo "$1"
    mkdir -p /data/nemesis 2>/dev/null || true
    echo "$1" >> "$LOG" 2>/dev/null || true
}

sys_rw() { /system/xbin/nemesis remount rw >/dev/null 2>&1; }
sys_ro() { /system/xbin/nemesis remount ro >/dev/null 2>&1 || true; }

chown_system() { chown 0.0 "$1" 2>/dev/null || chown 0:0 "$1" 2>/dev/null || true; }

# copy beside the target, then rename over it (a running app keeps its old copy)
put_file() {
    local _tmp="$2.lftmp"
    rm -f "$_tmp" 2>/dev/null
    cp "$1" "$_tmp" && cmp "$1" "$_tmp" >/dev/null 2>&1 || { rm -f "$_tmp" 2>/dev/null; return 1; }
    chmod 644 "$_tmp"; chown_system "$_tmp"
    mv "$_tmp" "$2" || { rm -f "$_tmp" 2>/dev/null; return 1; }
    [ -x /system/bin/restorecon ] && restorecon "$2" 2>/dev/null
    cmp "$1" "$2" >/dev/null 2>&1
}

wipe_dalvik() {
    rm -f /data/dalvik-cache/*"$APP"* /data/dalvik-cache/arm/*"$APP"* /cache/dalvik-cache/*"$APP"* 2>/dev/null || true
}

write_odex() {
    if [ -z "$BOOTCLASSPATH" ]; then
        export BOOTCLASSPATH=/system/framework/core.jar:/system/framework/conscrypt.jar:/system/framework/okhttp.jar:/system/framework/core-junit.jar:/system/framework/bouncycastle.jar:/system/framework/ext.jar:/system/framework/framework.jar:/system/framework/framework2.jar:/system/framework/telephony-common.jar:/system/framework/voip-common.jar:/system/framework/mms-common.jar:/system/framework/android.policy.jar:/system/framework/services.jar:/system/framework/apache-xml.jar:/system/framework/webviewchromium.jar:/system/framework/automotive.jar
        DEXOPT_BCP_FROM=fallback
    fi
    # once per part: what dexopt builds the odex against, for comparing with the running system
    if [ -z "$DEXOPT_LOGGED" ]; then
        DEXOPT_LOGGED=1
        log "dexopt boot classpath (${DEXOPT_BCP_FROM:-environment}): $BOOTCLASSPATH"
        log "dexopt flags m=y,u=n; system dalvik.vm.dexopt-flags=$(getprop dalvik.vm.dexopt-flags 2>/dev/null)"
    fi
    [ -x /system/bin/dexopt ] || return 1
    /system/bin/dexopt --preopt "$LIVE_APK" "$LIVE_ODEX" "m=y,u=n" || return 1
    [ -s "$LIVE_ODEX" ] || return 1
    chmod 644 "$LIVE_ODEX" 2>/dev/null || true
    chown_system "$LIVE_ODEX"
    [ -x /system/bin/restorecon ] && restorecon "$LIVE_ODEX" 2>/dev/null
    return 0
}

snapshot() {
    mkdir -p "$BACKUP_DIR" || return 1
    if [ ! -s "$BACKUP_DIR/$APP.apk" ]; then
        cp -f "$LIVE_APK" "$BACKUP_DIR/$APP.apk" && cmp "$LIVE_APK" "$BACKUP_DIR/$APP.apk" >/dev/null 2>&1 || return 1
        log "backed up $LIVE_APK"
    fi
    if [ ! -s "$BACKUP_DIR/$APP.odex" ]; then
        cp -f "$LIVE_ODEX" "$BACKUP_DIR/$APP.odex" && cmp "$LIVE_ODEX" "$BACKUP_DIR/$APP.odex" >/dev/null 2>&1 || return 1
        log "backed up $LIVE_ODEX"
    fi
    return 0
}

# Our APKs carry classes.dex, so at boot the package manager looks for the app in the Dalvik
# cache (not at the odex beside it) and, finding nothing, re-optimises it before the head unit
# finishes starting. The cache entry is the same optimised file as the odex, so put it there
# now. If Dalvik ever rejects it, it rebuilds it at boot as before.
prefill_dalvik() {
    local _odex="$1"
    local _apk="$2"
    local _cache="/data/dalvik-cache/system@app@${_apk##*/}@classes.dex"
    [ -s "$_odex" ] || return 0
    [ -d /data/dalvik-cache ] || return 0
    rm -f "${_cache}.tmp" 2>/dev/null || true
    if ! cp -f "$_odex" "${_cache}.tmp" 2>/dev/null || ! cmp "$_odex" "${_cache}.tmp" >/dev/null 2>&1; then
        rm -f "${_cache}.tmp" 2>/dev/null || true
        log "dalvik cache not filled for ${_apk##*/}; boot will optimize"
        return 0
    fi
    chmod 644 "${_cache}.tmp" 2>/dev/null || true
    chown 1000:1000 "${_cache}.tmp" 2>/dev/null || chown 1000.1000 "${_cache}.tmp" 2>/dev/null || true
    mv "${_cache}.tmp" "$_cache" 2>/dev/null || { rm -f "${_cache}.tmp" 2>/dev/null; return 0; }
    if [ -x /system/bin/restorecon ]; then
        restorecon "$_cache" 2>/dev/null || true
    fi
    log "dalvik cache filled for ${_apk##*/}"
    return 0
}

apply() {
    put_file "$NEW_APK" "$LIVE_APK" || { log "FAIL: write $LIVE_APK"; return 1; }
    rm -f "$LIVE_ODEX" 2>/dev/null
    if write_odex; then
        log "OK: $LIVE_APK replaced, odex written"
    else
        rm -f "$LIVE_ODEX" 2>/dev/null
        log "dexopt failed for $APP; boot will optimize"
    fi
    wipe_dalvik
    prefill_dalvik "$LIVE_ODEX" "$LIVE_APK"
    return 0
}

# restore: write the snapshot back (nothing to do when this part never installed)
restore() {
    [ -s "$BACKUP_DIR/$APP.apk" ] || { log "nothing of ours to undo"; return 0; }
    [ -s "$BACKUP_DIR/$APP.odex" ] || { log "FAIL: incomplete snapshot"; return 1; }
    sys_rw || { log "FAIL: remount /system rw"; return 1; }
    put_file "$BACKUP_DIR/$APP.apk" "$LIVE_APK" || { log "FAIL: restore $LIVE_APK"; sys_ro; return 1; }
    put_file "$BACKUP_DIR/$APP.odex" "$LIVE_ODEX" || { log "FAIL: restore $LIVE_ODEX"; sys_ro; return 1; }
    wipe_dalvik
    sync
    sys_ro
    log "restored stock $APP apk+odex"
    case "$BACKUP_DIR" in /data/nemesis/backup/wifi.client) rm -rf "$BACKUP_DIR" ;; esac
    return 0
}
