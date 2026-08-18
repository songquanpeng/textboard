#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CHECK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/textboard-checks.XXXXXX")
trap 'rm -rf "$CHECK_DIR"' EXIT INT TERM

swiftc -parse-as-library -enable-bare-slash-regex \
    "$ROOT_DIR/Sources/Textboard/Models.swift" \
    "$ROOT_DIR/Sources/Textboard/WorkspaceStore.swift" \
    "$ROOT_DIR/Tests/TextboardChecks/CheckMain.swift" \
    -o "$CHECK_DIR/TextboardChecks"

"$CHECK_DIR/TextboardChecks"
