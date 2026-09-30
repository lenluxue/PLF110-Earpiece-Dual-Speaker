#!/system/bin/sh

# Mount only the stable stereo-route and policy files.
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
exit 0
