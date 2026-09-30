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
replace_files vendor

# OplusFeatureConfigManager persists the static feature list in /data/system.
# Add the speaker-spatializer capability only through a temporary bind mount so
# disabling or uninstalling the module leaves the OEM cache unchanged.
PERSIST_TARGET=/data/system/oplus_persist_features.xml
PERSIST_SOURCE_DIR=/data/adb/plf110_earpiece_dual_speaker
PERSIST_SOURCE="$PERSIST_SOURCE_DIR/oplus_persist_features.xml"
PERSIST_TMP="$PERSIST_SOURCE.tmp.$$"
mkdir -p "$PERSIST_SOURCE_DIR"
if [ -r "$PERSIST_TARGET" ]; then
    if /system/bin/grep -q 'oplus.software.spatializer_speaker' "$PERSIST_TARGET"; then
        cp -pf "$PERSIST_TARGET" "$PERSIST_TMP"
    else
        /system/bin/awk '
            /<\/persist-features>/ && !added {
                print "  <feature name=\"oplus.software.spatializer_speaker\" />"
                added=1
            }
            { print }
        ' "$PERSIST_TARGET" > "$PERSIST_TMP"
    fi
    chown 1000:1000 "$PERSIST_TMP" 2>/dev/null
    chmod 0600 "$PERSIST_TMP"
    chcon u:object_r:system_data_file:s0 "$PERSIST_TMP" 2>/dev/null || true
    mv -f "$PERSIST_TMP" "$PERSIST_SOURCE"
    mount --bind "$PERSIST_SOURCE" "$PERSIST_TARGET"
fi

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
