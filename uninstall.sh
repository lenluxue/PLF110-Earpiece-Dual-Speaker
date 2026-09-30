#!/system/bin/sh

MODDIR=${0%/*}
STATE_DIR=/data/adb/plf110_earpiece_dual_speaker
LOG="$STATE_DIR/service.log"

echo "[$(date '+%F %T')] uninstall: clearing media device role" >> "$LOG"
if [ -x "$MODDIR/patch_gain.sh" ]; then
    sh "$MODDIR/patch_gain.sh" clear >> "$LOG" 2>&1 || true
fi
sh "$MODDIR/audio_ctl.sh" clear >> "$LOG" 2>&1

umount /data/system/oplus_persist_features.xml 2>/dev/null || true
rm -f "$STATE_DIR/oplus_persist_features.xml" "$STATE_DIR/oplus_persist_features.xml.tmp."* 2>/dev/null || true

rm -rf "$STATE_DIR"
