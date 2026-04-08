#!/bin/bash
set -euo pipefail

APP_NAME="MindPalantir"
BUILD_DIR=".build/debug"
BUNDLE_DIR="dist/${APP_NAME}.app"

echo "=== Building ${APP_NAME} ==="
swift build

echo "=== Creating .app bundle ==="
rm -rf "${BUNDLE_DIR}"
mkdir -p "${BUNDLE_DIR}/Contents/MacOS"
mkdir -p "${BUNDLE_DIR}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${BUNDLE_DIR}/Contents/MacOS/${APP_NAME}"

cat > "${BUNDLE_DIR}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.ibsen.MindPalantir</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

pkill -x "${APP_NAME}" 2>/dev/null || true
sleep 0.5

echo "=== Launching ${APP_NAME} ==="
/usr/bin/open -n "${BUNDLE_DIR}"
