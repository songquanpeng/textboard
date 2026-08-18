#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")

TEXTBOARD_UNIVERSAL=1 "$ROOT_DIR/scripts/build-app.sh"
ditto -c -k --sequesterRsrc --keepParent \
    "$ROOT_DIR/build/Textboard.app" \
    "$ROOT_DIR/build/Textboard-$VERSION-macos-universal.zip"

echo "$ROOT_DIR/build/Textboard-$VERSION-macos-universal.zip"
