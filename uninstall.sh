#!/system/bin/sh

MODDIR=${0%/*}
STATE_DIR=/data/adb/plf110_earpiece_dual_speaker
LOG="$STATE_DIR/service.log"

echo "[$(date '+%F %T')] uninstall: clearing media device role" >> "$LOG"
if [ -x "$MODDIR/patch_gain.sh" ]; then
    sh "$MODDIR/patch_gain.sh" clear >> "$LOG" 2>&1 || true
fi
sh "$MODDIR/audio_ctl.sh" clear >> "$LOG" 2>&1

rm -rf "$STATE_DIR"
