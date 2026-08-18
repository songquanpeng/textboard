#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/Textboard.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

if [ "${TEXTBOARD_UNIVERSAL:-0}" = "1" ]; then
    swift build --package-path "$ROOT_DIR" -c release --arch arm64
    ARM_BINARY=$(swift build --package-path "$ROOT_DIR" -c release --arch arm64 --show-bin-path)/Textboard
    swift build --package-path "$ROOT_DIR" -c release --arch x86_64
    X86_BINARY=$(swift build --package-path "$ROOT_DIR" -c release --arch x86_64 --show-bin-path)/Textboard
    BINARY="$BUILD_DIR/Textboard.universal"
    lipo -create "$ARM_BINARY" "$X86_BINARY" -output "$BINARY"
else
    swift build --package-path "$ROOT_DIR" -c release
    BINARY=$(swift build --package-path "$ROOT_DIR" -c release --show-bin-path)/Textboard
fi

cp "$BINARY" "$MACOS_DIR/Textboard"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

sed \
    -e "s/__VERSION__/$VERSION/g" \
    "$ROOT_DIR/Resources/Info.plist.template" > "$CONTENTS_DIR/Info.plist"

codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
