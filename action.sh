#!/system/bin/sh

MODDIR=${0%/*}
STATE_DIR=/data/adb/plf110_earpiece_dual_speaker
DISABLED="$STATE_DIR/disabled"
mkdir -p "$STATE_DIR"

if [ -f "$DISABLED" ]; then
    rm -f "$DISABLED"
    if [ -x "$MODDIR/patch_gain.sh" ]; then
        sh "$MODDIR/patch_gain.sh" apply || true
    fi
    if sh "$MODDIR/audio_ctl.sh" apply; then
        (sh "$MODDIR/audio_ctl.sh" monitor >> "$STATE_DIR/service.log" 2>&1 &)
        echo "Dual speaker enabled. AW882xx bottom-speaker attenuation is active."
    else
        echo "Failed to enable dual speaker. See $STATE_DIR/service.log."
        exit 1
    fi
else
    touch "$DISABLED"
    if [ -x "$MODDIR/patch_gain.sh" ]; then
        sh "$MODDIR/patch_gain.sh" clear || true
    fi
    sh "$MODDIR/audio_ctl.sh" clear
    echo "Dual speaker disabled."
fi
