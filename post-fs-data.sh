#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/coloros_compat.sh"

# Use PID 1's namespace so the audio HAL sees the selected policy files.
if [ "${PLF110_POLICY_NS:-0}" != 1 ] && [ -x /system/bin/nsenter ]; then
    export PLF110_POLICY_NS=1
    exec /system/bin/nsenter -t 1 -m -- /system/bin/sh "$0" "$@"
fi

case "$(coloros_major)" in
    16)
        mount_policy_tree "$MODDIR/legacy16" || exit 1
        ;;
    17)
        rmdir /data/adb/plf110_earpiece_dual_speaker/monitor.lock 2>/dev/null || true
        # Regenerate before mounting, also after an OTA. The previous firmware's
        # feature lists and audio policy must never become the source.
        # This directory contains only generated files belonging to this module.
        # Clear it so a removed endpoint after an OTA cannot retain an old copy.
        rm -rf "$MODDIR/.runtime/coloros17"
        prepare_coloros17_policies "" "$MODDIR/.runtime/coloros17" || exit 1
        mount_policy_tree "$MODDIR/.runtime/coloros17" || exit 1
        ;;
    *) echo "Unsupported ColorOS version; audio policy left unchanged" >&2; exit 1 ;;
esac
