#!/system/bin/sh

# The framework reads these properties while AudioService is initialized.
# Without them the vendor spatializer reports only multichannel support.
for resetprop in \
    /data/adb/sevenk/bin/resetprop \
    /data/adb/magisk/resetprop \
    /data/adb/ksu/bin/resetprop; do
    if [ -x "$resetprop" ]; then
        "$resetprop" -n ro.audio.stereo_spatialization_enabled true
        "$resetprop" -n ro.vendor.mtk.audio.spatializer_enable_stere 1
        break
    fi
done
exit 0
