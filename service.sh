#!/system/bin/sh

MODDIR=${0%/*}
BINDIR="$MODDIR/bin"
. "$MODDIR/coloros_compat.sh"
STATE_DIR=/data/adb/plf110_earpiece_dual_speaker
LOG="$STATE_DIR/service.log"
mkdir -p "$STATE_DIR"
exec >> "$LOG" 2>&1

echo "[$(date '+%F %T')] service start"

POLICY=/my_product/etc/audio_policy_configuration_a2dp_offload_enable_cg_enable.xml
[ -f "$POLICY" ] || POLICY=/vendor/etc/audio_policy_configuration_a2dp_offload_enable_cg_enable.xml
if /system/bin/grep -A5 'tagName="Earpiece"' "$POLICY" 2>/dev/null | /system/bin/grep -q 'AUDIO_CHANNEL_OUT_STEREO'; then
    echo "[$(date '+%F %T')] stereo earpiece policy active"
else
    echo "[$(date '+%F %T')] WARNING: stereo earpiece policy is not active; continuing with runtime route"
fi

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
    if [ -x "$BINDIR/patch_gain.sh" ]; then
        sh "$BINDIR/patch_gain.sh" clear || true
    fi
    sh "$BINDIR/audio_ctl.sh" clear
    exit 0
fi

# Do not touch AudioService until Android reports a completed boot.
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 30 ]; do
    i=$((i + 1))
    sleep 2
done

# AudioService can exist before AudioPolicy's native strategy list is ready.
# Keep the original ColorOS 16 behavior; retry the complete apply on ColorOS 17.
COLOROS_MAJOR=$(coloros_major)
MAX_APPLY_ATTEMPTS=6
if [ "$COLOROS_MAJOR" = 17 ]; then
    MAX_APPLY_ATTEMPTS=24
    sh "$BINDIR/audio_ctl.sh" status || \
        echo "[$(date '+%F %T')] audio strategy query not ready; retrying during apply"
else
    sh "$BINDIR/audio_ctl.sh" status || exit 1
fi

# Keep the gain-table overlay disabled; this firmware's parser crashes on it.
if [ -x "$BINDIR/patch_gain.sh" ]; then
    if sh "$BINDIR/patch_gain.sh" apply; then
        echo "[$(date '+%F %T')] gain-table overlay skipped"
    else
        echo "[$(date '+%F %T')] gain-table overlay unavailable; continuing"
    fi
fi

attempt=1
applied=0
while [ "$attempt" -le "$MAX_APPLY_ATTEMPTS" ]; do
    if [ "$COLOROS_MAJOR" = 17 ] && [ -f "$STATE_DIR/disabled" ]; then
        echo "[$(date '+%F %T')] disabled while waiting for audio initialization"
        sh "$BINDIR/audio_ctl.sh" clear || true
        exit 0
    fi
    echo "[$(date '+%F %T')] apply attempt $attempt"
    if sh "$BINDIR/audio_ctl.sh" apply; then
        echo "[$(date '+%F %T')] stereo route active; earpiece=left, AW88265=right, bottom=-16 dB"
        applied=1
        break
    fi
    attempt=$((attempt + 1))
    sleep 5
done

if [ "$applied" -ne 1 ]; then
    echo "[$(date '+%F %T')] failed after $MAX_APPLY_ATTEMPTS attempts"
    exit 1
fi

# Keep the earpiece media index aligned with the speaker setting.
sh "$BINDIR/audio_ctl.sh" monitor
