#!/system/bin/sh

# Shared by the installer and boot scripts. ColorOS versions are independent
# of the Android SDK on some vendor releases, so prefer the ROM property.
coloros_major() {
    rom=$(getprop ro.build.version.oplusrom 2>/dev/null)
    [ -n "$rom" ] || rom=$(getprop ro.build.version.opporom 2>/dev/null)
    case "$rom" in
        V16.*|16.*) echo 16; return ;;
        V17.*|17.*) echo 17; return ;;
        ?*) echo unsupported; return ;;
    esac
    case "$(getprop ro.build.version.sdk 2>/dev/null)" in
        36) echo 16 ;;
        37) echo 17 ;;
        *) echo unsupported ;;
    esac
}

prepare_coloros17_policies() {
    source_root=$1
    output_root=$2
    policy_count=0
    for policy in \
        "$source_root"/my_product/etc/audio_policy_configuration*.xml \
        "$source_root"/vendor/etc/audio_policy_configuration*.xml; do
        [ -f "$policy" ] || continue
        # Other Bluetooth/USB configurations have no earpiece endpoint.
        grep -q 'AUDIO_DEVICE_OUT_EARPIECE' "$policy" || continue
        relative=${policy#"$source_root"}
        output="$output_root$relative"
        mkdir -p "${output%/*}" || return 1
        if ! awk -f "$MODDIR/patch_earpiece.awk" "$policy" > "$output.tmp"; then
            echo "Cannot prepare stereo earpiece policy: $policy" >&2
            rm -f "$output.tmp"
            return 1
        fi
        chmod 0644 "$output.tmp" || return 1
        mv "$output.tmp" "$output" || return 1
        policy_count=$((policy_count + 1))
    done
    [ "$policy_count" -gt 0 ] || {
        echo "No stock earpiece audio policy found" >&2
        return 1
    }
}

mount_policy_tree() {
    tree=$1
    find "$tree" -type f 2>/dev/null | while IFS= read -r src; do
        dst=${src#"$tree"}
        [ -f "$dst" ] || continue
        mount --bind "$src" "$dst" || exit 1
    done
}
