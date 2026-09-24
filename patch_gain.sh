#!/system/bin/sh

STATE_DIR=/data/adb/plf110_earpiece_dual_speaker

# KernelSU/Magisk action shells can have a private mount namespace. Re-enter
# PID 1's namespace so the audio HAL sees the bind mounts as well.
if [ "${PLF110_GAIN_NS:-0}" != "1" ] && [ -x /system/bin/nsenter ]; then
    PLF110_GAIN_NS=1
    export PLF110_GAIN_NS
    exec /system/bin/nsenter -t 1 -m -- /system/bin/sh "$0" "$@"
fi

ODM_TABLE=/odm/etc/audio/audio_param/Volume_AudioParam.xml
VENDOR_TABLE=/vendor/etc/audio_param/Volume_AudioParam.xml

case "$1" in
    apply)
        echo "gain-table overlay disabled: modified table crashes the MediaTek audio HAL"
        ;;
    clear)
        /system/bin/umount "$ODM_TABLE" 2>/dev/null || true
        /system/bin/umount "$VENDOR_TABLE" 2>/dev/null || true
        ;;
    *)
        echo "usage: $0 {apply|clear}" >&2
        exit 64
        ;;
esac
