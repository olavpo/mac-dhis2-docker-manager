#!/usr/bin/env bash
# Build a release binary and assemble a minimal D2Manager.app bundle (LSUIElement).
# Usage: ./make-app.sh [--install]   (--install copies the app to /Applications and relaunches it)
set -euo pipefail

INSTALL=false
[[ "${1:-}" == "--install" ]] && INSTALL=true

APP_NAME="D2Manager"
BUILD_DIR=".build/release"
APP_DIR="$APP_NAME.app/Contents"

# Newer SDKs (macOS 27+) implement SwiftUI's @State as a macro whose plugin
# (SwiftUIMacros) only ships with full Xcode. When building with the Command
# Line Tools alone, fall back to the newest installed macOS 26.x SDK, where
# @State is still a plain property wrapper. Override by exporting SDKROOT.
DEV_DIR="$(xcode-select -p)"
if [[ -z "${SDKROOT:-}" ]] && ! find "$DEV_DIR" -path '*host/plugins*' -iname '*SwiftUIMacros*' 2>/dev/null | grep -q .; then
  FALLBACK_SDK="$(ls -d "$DEV_DIR"/SDKs/MacOSX26.[0-9]*.sdk 2>/dev/null | sort -V | tail -1 || true)"
  if [[ -n "$FALLBACK_SDK" ]]; then
    echo "SwiftUIMacros plugin not found; building against $FALLBACK_SDK"
    export SDKROOT="$FALLBACK_SDK"
  fi
fi

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

# Ad-hoc sign the whole bundle so macOS (e.g. SMAppService login items) sees a sealed app.
codesign --force --sign - "$APP_NAME.app"

if $INSTALL; then
  osascript -e "quit app \"$APP_NAME\"" 2>/dev/null || true
  rm -rf "/Applications/$APP_NAME.app"
  cp -R "$APP_NAME.app" "/Applications/$APP_NAME.app"
  open "/Applications/$APP_NAME.app"
  echo "Installed and launched /Applications/$APP_NAME.app"
else
  echo "Built $APP_NAME.app — run with --install to copy it to /Applications."
fi
