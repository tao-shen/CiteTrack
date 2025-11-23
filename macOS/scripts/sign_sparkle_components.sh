#!/bin/bash

# Script to sign Sparkle framework components with App Sandbox entitlements
# This script should be run as a Build Phase in Xcode after "Embed Frameworks"

set -e

# Get the app bundle path from the build settings
APP_BUNDLE="${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}"
SPARKLE_FRAMEWORK="${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework"
ENTITLEMENTS_FILE="${SRCROOT}/Sparkle.entitlements"

# Check if this is an App Store build (Release config or APP_STORE flag)
IS_APP_STORE=0

if echo "${OTHER_SWIFT_FLAGS}" | grep -q "APP_STORE"; then
    IS_APP_STORE=1
elif [ "${CONFIGURATION}" = "Release" ]; then
    # Fallback: Assume Release is for App Store if flag is missing but config matches
    IS_APP_STORE=1
fi

if [ "$IS_APP_STORE" -eq 1 ]; then
    echo "📦 App Store build detected (Config: ${CONFIGURATION}) - Removing Sparkle framework..."
    if [ -d "${SPARKLE_FRAMEWORK}" ]; then
        rm -rf "${SPARKLE_FRAMEWORK}"
        echo "✅ Removed Sparkle.framework for App Store submission"
    fi
    # Also remove any other Sparkle artifacts that might be lingering
    rm -rf "${APP_BUNDLE}/Contents/XPCServices/org.sparkle-project"*
    exit 0
fi

if [ ! -d "${SPARKLE_FRAMEWORK}" ]; then
    echo "⚠️  Sparkle framework not found, skipping signing"
    exit 0
fi

if [ ! -f "${ENTITLEMENTS_FILE}" ]; then
    echo "⚠️  Sparkle entitlements file not found at ${ENTITLEMENTS_FILE}, skipping signing"
    exit 0
fi

echo "🔐 Signing Sparkle framework components with App Sandbox entitlements..."

# Sign Autoupdate executable
AUTOUPDATE="${SPARKLE_FRAMEWORK}/Versions/B/Autoupdate"
if [ -f "${AUTOUPDATE}" ]; then
    codesign --force --sign "${CODE_SIGN_IDENTITY}" --entitlements "${ENTITLEMENTS_FILE}" "${AUTOUPDATE}" 2>/dev/null || true
    echo "✅ Signed Autoupdate"
fi

# Sign Updater.app
UPDATER_APP="${SPARKLE_FRAMEWORK}/Versions/B/Updater.app"
if [ -d "${UPDATER_APP}" ]; then
    # Sign the executable inside Updater.app
    UPDATER_EXEC="${UPDATER_APP}/Contents/MacOS/Updater"
    if [ -f "${UPDATER_EXEC}" ]; then
        codesign --force --sign "${CODE_SIGN_IDENTITY}" --entitlements "${ENTITLEMENTS_FILE}" "${UPDATER_EXEC}" 2>/dev/null || true
        echo "✅ Signed Updater.app executable"
    fi
    # Sign the app bundle itself
    codesign --force --sign "${CODE_SIGN_IDENTITY}" --entitlements "${ENTITLEMENTS_FILE}" "${UPDATER_APP}" 2>/dev/null || true
    echo "✅ Signed Updater.app bundle"
fi

# Sign Downloader.xpc
DOWNLOADER_XPC="${SPARKLE_FRAMEWORK}/Versions/B/XPCServices/Downloader.xpc"
if [ -d "${DOWNLOADER_XPC}" ]; then
    DOWNLOADER_EXEC="${DOWNLOADER_XPC}/Contents/MacOS/Downloader"
    if [ -f "${DOWNLOADER_EXEC}" ]; then
        codesign --force --sign "${CODE_SIGN_IDENTITY}" --entitlements "${ENTITLEMENTS_FILE}" "${DOWNLOADER_EXEC}" 2>/dev/null || true
        echo "✅ Signed Downloader.xpc executable"
    fi
    codesign --force --sign "${CODE_SIGN_IDENTITY}" --entitlements "${ENTITLEMENTS_FILE}" "${DOWNLOADER_XPC}" 2>/dev/null || true
    echo "✅ Signed Downloader.xpc bundle"
fi

# Sign Installer.xpc
INSTALLER_XPC="${SPARKLE_FRAMEWORK}/Versions/B/XPCServices/Installer.xpc"
if [ -d "${INSTALLER_XPC}" ]; then
    INSTALLER_EXEC="${INSTALLER_XPC}/Contents/MacOS/Installer"
    if [ -f "${INSTALLER_EXEC}" ]; then
        codesign --force --sign "${CODE_SIGN_IDENTITY}" --entitlements "${ENTITLEMENTS_FILE}" "${INSTALLER_EXEC}" 2>/dev/null || true
        echo "✅ Signed Installer.xpc executable"
    fi
    codesign --force --sign "${CODE_SIGN_IDENTITY}" --entitlements "${ENTITLEMENTS_FILE}" "${INSTALLER_XPC}" 2>/dev/null || true
    echo "✅ Signed Installer.xpc bundle"
fi

# Finally, sign the entire Sparkle framework
codesign --force --sign "${CODE_SIGN_IDENTITY}" "${SPARKLE_FRAMEWORK}" 2>/dev/null || true
echo "✅ Signed Sparkle framework"

echo "✅ Sparkle framework components signing complete"

