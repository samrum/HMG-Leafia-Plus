#!/system/bin/sh
# NEMESIS service (mode=restart): keep the internal eth0 link out of the hotspot's range.
# ADB over network the stock way (persist.service.adb.tcp.enable=1, which NEMESIS's TCP ADB
# sets) makes the stock init give eth0 192.168.0.123/24 at boot. The projection hotspot is
# wlan0 192.168.0.1/24, eth0's route comes first, so dnsmasq's replies to the phone leave
# through eth0 and the phone never gets an address: sooner or later (often after ~60 s) iOS
# gives up on the network and wireless CarPlay drops. The address is only there for ADB over
# network, and adbd listens on every interface, so taking it off eth0 keeps ADB working over
# Wi-Fi. Turning the stock switch off instead stops ADB over network on these units.
# The root shell NEMESIS gives may lack CAP_NET_ADMIN (ifconfig eth0 down: EPERM), so this asks netd.
export PATH=/data/nemesis/bin:/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
LOG=/data/nemesis/wireless.carplay.aa.log
log() { echo "$(date) eth0-guard: $1" >> "$LOG" 2>/dev/null; true; }
# The package folder is replaced on an update while this may keep running.
cd /

# "<eth0 address> <wlan0 address>" from netcfg, 0.0.0.0 when one has none. A pipe, not a
# here-document: mksh writes those to a temp file, every 5 s.
addrs() {
    netcfg 2>/dev/null | {
        _e=0.0.0.0; _w=0.0.0.0
        while read -r _if _st _ip _rest; do
            case "$_if" in
                eth0) _e=${_ip%%/*} ;;
                wlan0) _w=${_ip%%/*} ;;
            esac
        done
        echo "$_e $_w"
    }
}
clash() { [ "$1" != 0.0.0.0 ] && [ "$2" != 0.0.0.0 ] && [ "${1%.*}" = "${2%.*}" ]; }

# Logs only when something changes, so the shared install log can't fill up: ndc exits 0
# whatever netd answers, so success is read back from netcfg.
stuck=
while :; do
    set -- $(addrs)
    if clash "$1" "$2"; then
        ndc interface clearaddrs eth0 >/dev/null 2>&1
        _was=$1
        set -- $(addrs)
        if clash "$1" "$2"; then
            [ -n "$stuck" ] || log "WARN: eth0 has $1, in wlan0's range ($2), and netd did not remove it; retrying every minute"
            stuck=1
            sleep 55
        else
            log "eth0 had $_was, in wlan0's range: address removed so phones get one from the hotspot"
            stuck=
        fi
    fi
    sleep 5
done
