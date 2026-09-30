#!/system/bin/sh

# The framework reads these properties while AudioService is initialized.
# Without them the vendor spatializer reports only multichannel support.
MODDIR=${0%/*}

replace_files() {
    folder=$1
    find "$MODDIR/$folder" -type f 2>/dev/null | while read -r src; do
        dst=${src#$MODDIR}
        if [ -f "$dst" ]; then
            mount --bind "$src" "$dst"
        fi
    done
}

# KernelSU does not mount these custom partitions automatically on this device.
replace_files my_product
replace_files system_ext
replace_files vendor

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
