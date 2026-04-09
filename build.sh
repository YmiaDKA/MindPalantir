#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "🔨 Building..."
swift build 2>&1 | tail -1

APP=".build/debug/MindPalantir.app"
BIN=".build/debug/MindPalantir"

echo "📦 Creating app bundle..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/"

cat > "$APP/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MindPalantir</string>
    <key>CFBundleIdentifier</key>
    <string>com.mindpalantir.app</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleName</key>
    <string>MindPalantir</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSCalendarsUsageDescription</key>
    <string>MindPalantir imports calendar events to surface what matters now.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>MindPalantir watches your Desktop for new files to organize.</string>
    <key>NSDocumentsFolderUsageDescription</key>
    <string>MindPalantir watches your Documents for new files to organize.</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>MindPalantir watches your Downloads for new files to organize.</string>
</dict>
</plist>
PLIST

# Ad-hoc sign so macOS remembers permissions between runs
echo "✍️ Signing..."
codesign --force --sign - "$APP" 2>&1

echo "✅ Done: $APP"
