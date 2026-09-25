#!/system/bin/sh

MODDIR=${0%/*}
APP_PROCESS=/system/bin/app_process64
MEDIA_STRATEGY_ID=5
LEGACY_STRATEGY_ID=0
STATE_DIR=/data/adb/plf110_earpiece_dual_speaker
OFFSET_FILE="$STATE_DIR/earpiece_offset"
APPLIED_FILE="$STATE_DIR/earpiece_volume.applied"
MONITOR_LOCK="$STATE_DIR/monitor.lock"
MIXER_TOOL="$MODDIR/mixer_set_int"
HANDSET_CONTROL="Handset Volume"
HANDSET_BACKUP="$STATE_DIR/handset_volume.original"
HANDSET_GAIN_INDEX=0
LINEOUT_CONTROL="Lineout Volume"
LINEOUT_BACKUP="$STATE_DIR/lineout_volume.original"
LINEOUT_ATTENUATION_INDEX=31
SMARTPA_CONTROL="aw_dev_0_volume"
SMARTPA_BACKUP="$STATE_DIR/smartpa_volume.original"
SMARTPA_ATTENUATION_FILE="$STATE_DIR/smartpa_attenuation"
SMARTPA_DEFAULT_ATTENUATION=96
AW_REG_FILE=/sys/bus/i2c/devices/6-0034/reg
AW_CHANNEL_BACKUP="$STATE_DIR/aw_channel.original"
AW_CHANNEL_MASK=3072
AW_CHANNEL_RIGHT=2048

default_offset=160

get_offset() {
    value=$(cat "$OFFSET_FILE" 2>/dev/null)
    case "$value" in
        ''|*[!0-9]*) value=$default_offset ;;
    esac
    [ "$value" -le 160 ] || value=$default_offset
    echo "$value"
}

get_smartpa_attenuation() {
    value=$(cat "$SMARTPA_ATTENUATION_FILE" 2>/dev/null)
    case "$value" in
        ''|*[!0-9]*) value=$SMARTPA_DEFAULT_ATTENUATION ;;
    esac
    [ "$value" -le 720 ] || value=$SMARTPA_DEFAULT_ATTENUATION
    echo "$value"
}

get_speaker_index() {
    raw=$(/system/bin/settings get system volume_music_speaker 2>/dev/null)
    case "$raw" in
        ''|null|*[!0-9]*) return 1 ;;
    esac
    value=$((raw & 4095))
    [ "$value" -ge 0 ] && [ "$value" -le 160 ] || return 1
    echo "$value"
}

get_earpiece_index() {
    raw=$(/system/bin/settings get system volume_music_earpiece 2>/dev/null)
    case "$raw" in
        ''|null|*[!0-9]*) return 1 ;;
    esac
    value=$((raw & 4095))
    [ "$value" -ge 0 ] && [ "$value" -le 160 ] || return 1
    echo "$value"
}

run_route() {
    CLASSPATH="$MODDIR/strategy_route.dex" \
        "$APP_PROCESS" /system/bin StrategyRoute "$MEDIA_STRATEGY_ID" 1 "$1"
}

clear_legacy_route() {
    CLASSPATH="$MODDIR/strategy_route.dex" \
        "$APP_PROCESS" /system/bin StrategyRoute "$LEGACY_STRATEGY_ID" 1 clear
}

set_earpiece_volume() {
    CLASSPATH="$MODDIR/device_volume.dex" \
        "$APP_PROCESS" /system/bin DeviceVolume 1 "$1"
}

get_handset_volume() {
    [ -x "$MIXER_TOOL" ] || return 1
    "$MIXER_TOOL" get "$HANDSET_CONTROL" 2>/dev/null
}

set_handset_volume() {
    [ -x "$MIXER_TOOL" ] || return 1
    "$MIXER_TOOL" set "$HANDSET_CONTROL" "$1" >/dev/null 2>&1
}

get_lineout_volume() {
    [ -x "$MIXER_TOOL" ] || return 1
    "$MIXER_TOOL" get "$LINEOUT_CONTROL" 2>/dev/null
}

set_lineout_volume() {
    [ -x "$MIXER_TOOL" ] || return 1
    "$MIXER_TOOL" set "$LINEOUT_CONTROL" "$1" >/dev/null 2>&1
}

get_smartpa_volume() {
    [ -x "$MIXER_TOOL" ] || return 1
    "$MIXER_TOOL" get "$SMARTPA_CONTROL" 2>/dev/null
}

set_smartpa_volume() {
    [ -x "$MIXER_TOOL" ] || return 1
    "$MIXER_TOOL" set "$SMARTPA_CONTROL" "$1" >/dev/null 2>&1
}

get_aw_i2s_reg() {
    [ -r "$AW_REG_FILE" ] || return 1
    value=$(/system/bin/grep '^reg:0x06=' "$AW_REG_FILE" 2>/dev/null | /system/bin/cut -d= -f2)
    case "$value" in
        0x[0-9a-fA-F]*) ;;
        *) return 1 ;;
    esac
    echo $((value))
}

set_aw_channel_bits() {
    requested=$1
    case "$requested" in
        0|1024|2048|3072) ;;
        *) return 1 ;;
    esac

    current=$(get_aw_i2s_reg) || return 1
    target=$(((current & 0xf3ff) | requested))
    if [ "$target" -ne "$current" ]; then
        printf '6 %04x\n' "$target" > "$AW_REG_FILE" || return 1
    fi

    updated=$(get_aw_i2s_reg) || return 1
    [ $((updated & AW_CHANNEL_MASK)) -eq "$requested" ]
}

ensure_aw_right_channel() {
    [ -e "$AW_REG_FILE" ] || return 1

    if [ ! -f "$AW_CHANNEL_BACKUP" ]; then
        current=$(get_aw_i2s_reg) || return 1
        printf '%s\n' "$((current & AW_CHANNEL_MASK))" > "$AW_CHANNEL_BACKUP"
    fi

    current=$(get_aw_i2s_reg) || return 1
    if [ $((current & AW_CHANNEL_MASK)) -ne "$AW_CHANNEL_RIGHT" ]; then
        set_aw_channel_bits "$AW_CHANNEL_RIGHT" || return 1
        echo "AW88265 I2S input channel set to right"
    fi
}

restore_aw_channel() {
    original=$(cat "$AW_CHANNEL_BACKUP" 2>/dev/null)
    case "$original" in
        0|1024|2048|3072) set_aw_channel_bits "$original" ;;
        *) return 0 ;;
    esac
}

ensure_handset_gain() {
    [ -x "$MIXER_TOOL" ] || return 1

    if [ ! -f "$HANDSET_BACKUP" ]; then
        original=$(get_handset_volume) || return 1
        case "$original" in
            ''|*[!0-9]*) return 1 ;;
        esac
        printf '%s\n' "$original" > "$HANDSET_BACKUP"
    fi

    current=$(get_handset_volume) || return 1
    if [ "$current" != "$HANDSET_GAIN_INDEX" ]; then
        set_handset_volume "$HANDSET_GAIN_INDEX" || return 1
        echo "handset hardware gain set: $current -> $HANDSET_GAIN_INDEX"
    fi
}

ensure_lineout_attenuation() {
    [ -x "$MIXER_TOOL" ] || return 1

    if [ ! -f "$LINEOUT_BACKUP" ]; then
        original=$(get_lineout_volume) || return 1
        case "$original" in
            ''|*[!0-9]*) return 1 ;;
        esac
        printf '%s\n' "$original" > "$LINEOUT_BACKUP"
    fi

    current=$(get_lineout_volume) || return 1
    if [ "$current" != "$LINEOUT_ATTENUATION_INDEX" ]; then
        set_lineout_volume "$LINEOUT_ATTENUATION_INDEX" || return 1
        echo "lineout hardware gain set: $current -> $LINEOUT_ATTENUATION_INDEX"
    fi
}

ensure_smartpa_attenuation() {
    [ -x "$MIXER_TOOL" ] || return 1

    if [ ! -f "$SMARTPA_BACKUP" ]; then
        original=$(get_smartpa_volume) || return 1
        case "$original" in
            ''|*[!0-9]*) return 1 ;;
        esac
        printf '%s\n' "$original" > "$SMARTPA_BACKUP"
    fi

    target=$(get_smartpa_attenuation)
    current=$(get_smartpa_volume) || return 1
    if [ "$current" != "$target" ]; then
        set_smartpa_volume "$target" || return 1
        echo "AW882xx bottom-speaker attenuation set: $current -> $target (0.125 dB steps)"
    fi
}

sync_earpiece_volume() {
    speaker=$(get_speaker_index) || return 1
    offset=$(get_offset)
    target=$((speaker + offset))
    [ "$target" -le 160 ] || target=160

    current=$(get_earpiece_index) || current=-1
    if [ "$current" = "$target" ]; then
        printf '%s\n' "$target" > "$APPLIED_FILE"
        return 0
    fi

    set_earpiece_volume "$target" || return $?
    printf '%s\n' "$target" > "$APPLIED_FILE"
    echo "earpiece media index synced: speaker=$speaker offset=$offset target=$target"
}

restore_earpiece_volume() {
    backup="$STATE_DIR/earpiece_volume.original"
    value=$(cat "$backup" 2>/dev/null)
    case "$value" in
        ''|*[!0-9]*) return 0 ;;
    esac
    [ "$value" -le 160 ] || return 0
    set_earpiece_volume "$value"
    rm -f "$APPLIED_FILE"
}

monitor_volume() {
    mkdir "$MONITOR_LOCK" 2>/dev/null || return 0
    while [ -d "$MODDIR" ] && [ -d "$STATE_DIR" ] && [ ! -f "$STATE_DIR/disabled" ]; do
        ensure_handset_gain
        ensure_lineout_attenuation
        ensure_smartpa_attenuation
        ensure_aw_right_channel
        sync_earpiece_volume
        sleep 0.5
    done
    rm -rf "$MONITOR_LOCK"
}

case "$1" in
    apply)
        clear_legacy_route >/dev/null 2>&1 || true
        run_route keep || exit $?
        ensure_handset_gain || exit $?
        ensure_lineout_attenuation || exit $?
        ensure_smartpa_attenuation || exit $?
        ensure_aw_right_channel || exit $?
        sync_earpiece_volume || exit $?
        ;;
    sync)
        sync_earpiece_volume
        ;;
    monitor)
        monitor_volume
        ;;
    clear)
        restore_aw_channel
        run_route clear
        clear_legacy_route >/dev/null 2>&1 || true
        restore_earpiece_volume
        original=$(cat "$HANDSET_BACKUP" 2>/dev/null)
        case "$original" in
            ''|*[!0-9]*) ;;
            *) set_handset_volume "$original" ;;
        esac
        original=$(cat "$LINEOUT_BACKUP" 2>/dev/null)
        case "$original" in
            ''|*[!0-9]*) ;;
            *) [ "$original" -le 31 ] && set_lineout_volume "$original" ;;
        esac
        original=$(cat "$SMARTPA_BACKUP" 2>/dev/null)
        case "$original" in
            ''|*[!0-9]*) ;;
            *) [ "$original" -le 720 ] && set_smartpa_volume "$original" ;;
        esac
        ;;
    restore)
        set_earpiece_volume "$2"
        ;;
    *)
        echo "usage: $0 {apply|sync|monitor|clear|restore INDEX}" >&2
        exit 64
        ;;
esac
