#!/bin/bash

# MAS build script for CiteTrack (without Sparkle, with iCloud entitlements)
# Usage: ./scripts/build_mas.sh

set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="CiteTrack"
BUNDLE_ID="com.citetrack.app"
VERSION=$(date +"%Y.%m.%d")
BUILD_DIR="build_mas"
SOURCES_DIR="Sources"
ENTITLEMENTS_FILE="CiteTrack.entitlements"

echo "🧹 Cleaning..."
rm -rf "$BUILD_DIR" "$APP_NAME.app"
mkdir -p "$BUILD_DIR"

# Collect all swift sources except the legacy alt entry point
echo "🔎 Collecting source files..."
# Exclude alternative/backup/duplicate sources that cause symbol conflicts
SWIFT_FILES=( $(
  find "$SOURCES_DIR" -name "*.swift" \
    ! -name "main_v1.1.3.swift" \
    ! -name "main_localized.swift" \
    ! -name "*backup*.swift" \
    ! -name "ModernChartsViewController.swift" \
    ! -name "ModernChartsWindowController.swift" \
    ! -name "StatisticsView.swift" \
    ! -name "SettingsWindow_v1.1.3.swift" \
    -print
) )

# Add selected shared sources (CloudKit service only)
if [ -f "Shared/Services/CloudKitSyncService.swift" ]; then
  SWIFT_FILES+=("Shared/Services/CloudKitSyncService.swift")
fi

echo "🛠️  Compiling (MAS target)..."
swiftc -O -target arm64-apple-macos11 \
  -D APP_STORE \
  -framework Foundation -framework AppKit -framework CloudKit \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  "${SWIFT_FILES[@]}" \
  -o "$BUILD_DIR/$APP_NAME"

echo "📦 Creating .app bundle..."
APP_BUNDLE="$APP_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
  <key>CFBundleIconFile</key><string>app_icon</string>
</dict>
</plist>
EOF

# Icon (if exists)
if [ -f "assets/app_icon.icns" ]; then
  cp "assets/app_icon.icns" "$APP_BUNDLE/Contents/Resources/app_icon.icns"
fi

# Sign with ad-hoc for local run; App Store Connect will require proper signing in Xcode
if command -v codesign >/dev/null 2>&1; then
  echo "🔐 Ad-hoc codesigning..."
  codesign --force --deep --options runtime --entitlements "$ENTITLEMENTS_FILE" --sign - "$APP_BUNDLE" || true
fi

echo "✅ MAS build ready: $APP_BUNDLE"
echo "📄 Entitlements: $ENTITLEMENTS_FILE"
echo "ℹ️ Next steps: Open the project in Xcode to archive with your App Store profile and upload via Organizer."
