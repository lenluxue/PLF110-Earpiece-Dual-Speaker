#!/system/bin/sh

ui_print " "
ui_print "  PLF110 Earpiece/Speaker Stereo v2.5.1"
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

MODDIR=$MODPATH
. "$MODDIR/coloros_compat.sh"
COLOROS_MAJOR=$(coloros_major)
case "$COLOROS_MAJOR" in
    16) ui_print "- ColorOS 16: original routing helpers and policy files" ;;
    17)
        prepare_coloros17_policies "" "$MODPATH/.runtime/coloros17" || abort "Cannot prepare ColorOS 17 audio policy"
        ui_print "- ColorOS 17: stereo earpiece profiles generated from current firmware"
        ;;
    *) abort "Only ColorOS 16 and ColorOS 17 are supported" ;;
esac

STATE_DIR=/data/adb/plf110_earpiece_dual_speaker
BACKUP="$STATE_DIR/earpiece_volume.original"
mkdir -p "$STATE_DIR"
printf '128\n' > "$STATE_DIR/smartpa_attenuation"
printf '0\n' > "$STATE_DIR/earpiece_offset"

if [ ! -f "$BACKUP" ]; then
    if [ "$COLOROS_MAJOR" = 17 ]; then
        raw=$(CLASSPATH="$MODPATH/bin/audio_compat17.dex" /system/bin/app_process64 -Xmx64m /system/bin AudioCompat17 get 1) || abort "Cannot query ColorOS 17 device volume"
    else
        raw=$(/system/bin/settings get system volume_music_earpiece 2>/dev/null)
    fi
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

ui_print "- Stereo output: earpiece left + bottom AW88265 speaker right"
ui_print "- Earpiece media index follows the speaker media index"
ui_print "- Handset hardware gain: maximum vendor index (0)"
ui_print "- Legacy Lineout Volume override is restored, not forced"
ui_print "- AW88265 I2S channel select: right (CHSEL=2)"
ui_print "- AW882xx bottom smart-PA attenuation: 128 steps (-16 dB)"
ui_print "- Receiver route: left only; bottom AW88265 route: right only"
ui_print "- Earpiece policy profile is stereo to preserve the left channel"
if [ "$COLOROS_MAJOR" = 16 ]; then
    ui_print "- Original ColorOS 16 spatializer policy retained"
else
    ui_print "- ColorOS 17 stock feature lists and other audio endpoints preserved"
fi
ui_print "- Gain table overlay disabled for MediaTek HAL stability"
ui_print "- Reboot after installation"
ui_print "- The module action button toggles the route immediately"
if [ -f "$STATE_DIR/disabled" ]; then
    ui_print "- Route is currently disabled; use module action once to enable it"
fi

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/customize.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/bin/audio_ctl.sh" 0 0 0755
set_perm_recursive "$MODPATH/legacy16" 0 0 0755 0644
set_perm "$MODPATH/coloros_compat.sh" 0 0 0755
set_perm "$MODPATH/bin/patch_gain.sh" 0 0 0755
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/bin/mixer_set_int" 0 0 0755
set_perm "$MODPATH/bin/mixer_set_route" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
