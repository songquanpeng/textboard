#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=$(node -p "require('$ROOT_DIR/package.json').version")
TARGET=aarch64-apple-darwin
NOTARY_PROFILE=${TEXTBOARD_NOTARY_PROFILE:-TextboardNotary}

SIGNING_IDENTITY=${APPLE_SIGNING_IDENTITY:-}
if [ -z "$SIGNING_IDENTITY" ]; then
    SIGNING_IDENTITY=$(
        security find-identity -v -p codesigning \
            | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' \
            | head -n 1
    )
fi

case "$SIGNING_IDENTITY" in
    "Developer ID Application: "*) ;;
    *)
        echo "未找到 Developer ID Application 签名证书。" >&2
        echo "请先在 Apple Developer 后台创建证书并安装到登录钥匙串。" >&2
        exit 1
        ;;
esac

if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "未找到或无法使用公证钥匙串配置：$NOTARY_PROFILE" >&2
    echo "请先执行 README 中的 notarytool store-credentials 命令。" >&2
    exit 1
fi

export APPLE_SIGNING_IDENTITY="$SIGNING_IDENTITY"
unset APPLE_ID APPLE_PASSWORD APPLE_TEAM_ID APPLE_API_ISSUER APPLE_API_KEY APPLE_API_KEY_PATH

cd "$ROOT_DIR"
npm run tauri:build -- --target "$TARGET" --bundles app,dmg

BUNDLE_DIR="$ROOT_DIR/src-tauri/target/$TARGET/release/bundle"
APP_PATH="$BUNDLE_DIR/macos/Textboard.app"
DMG_PATH="$BUNDLE_DIR/dmg/Textboard_${VERSION}_aarch64.dmg"
OUTPUT_DIR="$ROOT_DIR/build"
OUTPUT_PATH="$OUTPUT_DIR/Textboard-${VERSION}-macos-arm64.dmg"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"

mkdir -p "$OUTPUT_DIR"
ditto "$DMG_PATH" "$OUTPUT_PATH"
shasum -a 256 "$OUTPUT_PATH"
echo "$OUTPUT_PATH"
