#!/bin/sh
set -eu
cd "${0%/*}/.."
BUILD_DIR=$(mktemp -d "${TMPDIR:-/data/local/tmp}/plf110-audio-build.XXXXXX")
trap 'rm -rf "$BUILD_DIR"' EXIT HUP INT TERM
javac --release 8 -Xlint:-options -d "$BUILD_DIR" tools/AudioCompat17.java
java -Xmx256m -cp "${D8_JAR:-/data/data/com.termux/files/usr/share/java/d8.jar}" \
    com.android.tools.r8.D8 --min-api 26 --output "$BUILD_DIR" "$BUILD_DIR/AudioCompat17.class"
cp "$BUILD_DIR/classes.dex" audio_compat17.dex
version=$(sed -n 's/^version=//p' module.prop)
mkdir -p dist
archive="dist/PLF110-Earpiece-Dual-Speaker-v$version.zip"
# Build into a fresh archive. Repository images and development tools are not
# part of the installable module.
zip -q -9 -r "$BUILD_DIR/module.zip" \
    module.prop customize.sh post-fs-data.sh service.sh action.sh audio_ctl.sh \
    coloros_compat.sh patch_earpiece.awk patch_gain.sh uninstall.sh \
    mixer_set_int mixer_set_route strategy_route.dex device_volume.dex audio_compat17.dex \
    legacy16 LICENSE README.md README.zh-CN.md README.id.md
mv "$BUILD_DIR/module.zip" "$archive"
unzip -t "$archive" | tail -1
ls -l "$archive"
sha256sum "$archive"
