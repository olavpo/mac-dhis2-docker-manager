#!/usr/bin/env bash
# Build a release binary and assemble a minimal D2Manager.app bundle (LSUIElement).
set -euo pipefail

APP_NAME="D2Manager"
BUILD_DIR=".build/release"
APP_DIR="$APP_NAME.app/Contents"

swift build -c release

rm -rf "$APP_NAME.app"
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/MacOS/$APP_NAME"

cat > "$APP_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>org.dhis2.d2manager</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

echo "Built $APP_NAME.app — move it to /Applications or add to Login Items."
