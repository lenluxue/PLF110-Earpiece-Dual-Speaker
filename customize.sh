#!/system/bin/sh

ui_print " "
ui_print "  PLF110 Earpiece Dual Speaker v2.0.6"
ui_print " "

device=$(getprop ro.product.device)
vendor_device=$(getprop ro.vendor.product.device)
model=$(getprop ro.product.model)
case "$device:$vendor_device:$model" in
    PLF110:*|*:PLF110:*|*:*:PLF110) ;;
    *)
        ui_print "! This build only supports PLF110."
        ui_print "! Current device: ${device:-unknown} / ${model:-unknown}"
        abort "Unsupported device"
        ;;
esac

STATE_DIR=/data/adb/plf110_earpiece_dual_speaker
BACKUP="$STATE_DIR/earpiece_volume.original"
mkdir -p "$STATE_DIR"

if [ ! -f "$BACKUP" ]; then
    raw=$(/system/bin/settings get system volume_music_earpiece 2>/dev/null)
    case "$raw" in
        ''|null|*[!0-9]*) ;;
        *)
            value=$((raw & 4095))
            if [ "$value" -ge 0 ] && [ "$value" -le 160 ]; then
                echo "$value" > "$BACKUP"
                ui_print "- Saved current earpiece media volume: $value/160"
            fi
            ;;
    esac
fi

ui_print "- Media output: speaker + earpiece"
ui_print "- Earpiece media index is held at the media maximum 160"
ui_print "- Handset hardware gain: maximum vendor index (0)"
ui_print "- Bottom speaker hardware attenuation: Lineout Volume 31 (-40 dB vendor sentinel)"
ui_print "- AW882xx bottom smart-PA attenuation: 96 steps (-12 dB)"
ui_print "- Gain table overlay disabled for MediaTek HAL stability"
ui_print "- Reboot after installation"
ui_print "- The module action button toggles the route immediately"

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/customize.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/audio_ctl.sh" 0 0 0755
set_perm "$MODPATH/patch_gain.sh" 0 0 0755
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/mixer_set_int" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
