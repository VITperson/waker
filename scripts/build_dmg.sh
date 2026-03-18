#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$BUILD_DIR/dmg-staging"
ICON_WORK_DIR="$BUILD_DIR/generated-icon"
ICONSET_DIR="$ICON_WORK_DIR/Waker.iconset"
ICON_PNG="$ICON_WORK_DIR/waker-icon.png"
APP_BUNDLE="$DIST_DIR/Waker.app"
DMG_PATH="$DIST_DIR/Waker.dmg"
EXECUTABLE_DEST="$APP_BUNDLE/Contents/MacOS/Waker"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
ICON_DEST="$APP_BUNDLE/Contents/Resources/Waker.icns"
ICON_PREVIEW="$DIST_DIR/Waker-icon.png"

mkdir -p "$BUILD_DIR"
find "$BUILD_DIR" -mindepth 1 -maxdepth 1 ! -name '.DS_Store' -exec rm -rf {} +

swift build -c release --package-path "$ROOT_DIR" >/dev/null
EXECUTABLE_SOURCE="$(swift build -c release --package-path "$ROOT_DIR" --show-bin-path)/waker"

rm -rf "$APP_BUNDLE" "$STAGING_DIR"
rm -rf "$ICON_WORK_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$DIST_DIR" "$STAGING_DIR" "$ICONSET_DIR"

swift "$ROOT_DIR/scripts/generate_app_icon.swift" "$ICON_WORK_DIR" >/dev/null
cp "$ICON_PNG" "$ICON_PREVIEW"

sips -z 16 16 "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$ICON_DEST"

cp "$EXECUTABLE_SOURCE" "$EXECUTABLE_DEST"
chmod +x "$EXECUTABLE_DEST"

cat > "$INFO_PLIST" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Waker</string>
    <key>CFBundleIdentifier</key>
    <string>com.vibecoding.waker</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>Waker</string>
    <key>CFBundleName</key>
    <string>Waker</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

codesign \
    --force \
    --deep \
    --sign - \
    --identifier com.vibecoding.waker \
    --requirements '=designated => identifier "com.vibecoding.waker"' \
    "$APP_BUNDLE" >/dev/null

cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "Waker" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

echo "App bundle: $APP_BUNDLE"
echo "DMG: $DMG_PATH"
echo "Icon preview: $ICON_PREVIEW"
