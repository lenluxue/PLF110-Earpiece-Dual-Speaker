#!/system/bin/sh

MODDIR=${0%/*}
STATE_DIR=/data/adb/plf110_earpiece_dual_speaker
LOG="$STATE_DIR/service.log"
mkdir -p "$STATE_DIR"
exec >> "$LOG" 2>&1

echo "[$(date '+%F %T')] service start"

i=0
while [ "$i" -lt 60 ]; do
    if /system/bin/service check audio 2>&1 | /system/bin/grep -q 'found'; then
        break
    fi
    i=$((i + 1))
    sleep 2
done

if [ -f "$STATE_DIR/disabled" ]; then
    echo "[$(date '+%F %T')] disabled by action button"
    if [ -x "$MODDIR/patch_gain.sh" ]; then
        sh "$MODDIR/patch_gain.sh" clear || true
    fi
    sh "$MODDIR/audio_ctl.sh" clear
    exit 0
fi

# Do not touch AudioService until Android reports a completed boot.
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 30 ]; do
    i=$((i + 1))
    sleep 2
done

# Keep the gain-table overlay disabled; this firmware's parser crashes on it.
if [ -x "$MODDIR/patch_gain.sh" ]; then
    if sh "$MODDIR/patch_gain.sh" apply; then
        echo "[$(date '+%F %T')] gain-table overlay skipped"
    else
        echo "[$(date '+%F %T')] gain-table overlay unavailable; continuing"
    fi
fi

attempt=1
applied=0
while [ "$attempt" -le 6 ]; do
    echo "[$(date '+%F %T')] apply attempt $attempt"
    if sh "$MODDIR/audio_ctl.sh" apply; then
        echo "[$(date '+%F %T')] dual route active; AW882xx bottom-speaker balance control active"
        applied=1
        break
    fi
    attempt=$((attempt + 1))
    sleep 5
done

if [ "$applied" -ne 1 ]; then
    echo "[$(date '+%F %T')] failed after six attempts"
    exit 1
fi

# Keep the earpiece media index aligned with the speaker setting.
sh "$MODDIR/audio_ctl.sh" monitor
