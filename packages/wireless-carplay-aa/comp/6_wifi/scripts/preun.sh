#!/system/bin/sh
. ./scripts/common.sh
log "preuninstall wifi.client"
restore || { log "keeping $BACKUP_DIR"; exit 1; }
exit 0
