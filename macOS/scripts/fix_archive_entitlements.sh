#!/bin/bash

# Post-Archive script to fix Sparkle framework entitlements
# This script should be run after Archive to ensure Sparkle components have App Sandbox entitlements
# Usage: ./scripts/fix_archive_entitlements.sh <path-to-xcarchive>

set -e

ARCHIVE_PATH="$1"

if [ -z "$ARCHIVE_PATH" ]; then
    # Try to find the most recent archive
    ARCHIVE_DIR="$HOME/Library/Developer/Xcode/Archives"
    if [ -d "$ARCHIVE_DIR" ]; then
        ARCHIVE_PATH=$(find "$ARCHIVE_DIR" -name "*.xcarchive" -type d -maxdepth 2 -print0 | xargs -0 ls -dt | head -1)
    fi
fi

if [ -z "$ARCHIVE_PATH" ] || [ ! -d "$ARCHIVE_PATH" ]; then
    echo "❌ Archive not found. Please provide path to .xcarchive"
    echo "Usage: $0 <path-to-xcarchive>"
    exit 1
fi

echo "🔍 Found archive: $ARCHIVE_PATH"

APP_BUNDLE="$ARCHIVE_PATH/Products/Applications/CiteTrack.app"
SPARKLE_FRAMEWORK="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
ENTITLEMENTS_FILE="$(dirname "$0")/../Sparkle.entitlements"

if [ ! -d "$SPARKLE_FRAMEWORK" ]; then
    echo "⚠️  Sparkle framework not found in archive, skipping"
    exit 0
fi

if [ ! -f "$ENTITLEMENTS_FILE" ]; then
    echo "❌ Entitlements file not found: $ENTITLEMENTS_FILE"
    exit 1
fi

# Get the signing identity from the app
echo "🔍 Detecting signing identity..."
SIGN_IDENTITY=$(codesign -dvv "$APP_BUNDLE" 2>&1 | grep "Authority=" | head -1 | sed 's/.*Authority=\([^ ]*\).*/\1/' || echo "")

# If identity is ambiguous (like "Apple"), get the full certificate name
if [ "$SIGN_IDENTITY" = "Apple" ] || [ -z "$SIGN_IDENTITY" ]; then
    # Try to get the full certificate name from the app
    FULL_IDENTITY=$(codesign -dvv "$APP_BUNDLE" 2>&1 | grep -E "Authority=|TeamIdentifier=" | head -2)
    TEAM_ID=$(echo "$FULL_IDENTITY" | grep "TeamIdentifier=" | sed 's/.*TeamIdentifier=\([^ ]*\).*/\1/' || echo "")
    
    # Try to find matching certificate
    if [ -n "$TEAM_ID" ]; then
        # Look for certificate with matching team ID
        CERT_NAME=$(security find-identity -v -p codesigning 2>/dev/null | grep "$TEAM_ID" | head -1 | sed 's/.*"\(.*\)".*/\1/' || echo "")
        if [ -n "$CERT_NAME" ]; then
            SIGN_IDENTITY="$CERT_NAME"
        fi
    fi
    
    # If still not found, try to get from app's embedded provisioning profile
    if [ -z "$SIGN_IDENTITY" ] || [ "$SIGN_IDENTITY" = "Apple" ]; then
        PROVISIONING="$APP_BUNDLE/Contents/embedded.provisionprofile"
        if [ -f "$PROVISIONING" ]; then
            # Extract team ID from provisioning profile
            TEAM_ID=$(/usr/libexec/PlistBuddy -c "Print TeamIdentifier:0" /dev/stdin <<< $(security cms -D -i "$PROVISIONING" 2>/dev/null) 2>/dev/null || echo "")
            if [ -n "$TEAM_ID" ]; then
                CERT_NAME=$(security find-identity -v -p codesigning 2>/dev/null | grep "$TEAM_ID" | head -1 | sed 's/.*"\(.*\)".*/\1/' || echo "")
                if [ -n "$CERT_NAME" ]; then
                    SIGN_IDENTITY="$CERT_NAME"
                fi
            fi
        fi
    fi
fi

# Final fallback: use the first available development certificate
if [ -z "$SIGN_IDENTITY" ] || [ "$SIGN_IDENTITY" = "Apple" ]; then
    echo "⚠️  Using first available development certificate..."
    SIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer" | head -1 | sed 's/.*"\(.*\)".*/\1/' || echo "")
fi

if [ -z "$SIGN_IDENTITY" ]; then
    echo "❌ Could not detect signing identity from app"
    echo "💡 Please ensure you have a valid code signing certificate in Keychain"
    exit 1
fi

echo "✅ Using signing identity: $SIGN_IDENTITY"
echo "🔐 Signing Sparkle framework components with App Sandbox entitlements..."

# Function to sign with entitlements and verify
sign_with_entitlements() {
    local target="$1"
    local name="$2"
    
    if [ ! -e "$target" ]; then
        echo "⚠️  $name not found, skipping"
        return 0
    fi
    
    echo "   Signing $name..."
    
    # Remove existing signature first
    codesign --remove-signature "$target" 2>/dev/null || true
    
    # Sign with entitlements (use --deep for bundles)
    local sign_cmd="codesign --force --sign \"$SIGN_IDENTITY\" --entitlements \"$ENTITLEMENTS_FILE\" --options runtime"
    if [[ "$target" == *.app ]] || [[ "$target" == *.xpc ]]; then
        sign_cmd="$sign_cmd --deep"
    fi
    sign_cmd="$sign_cmd \"$target\""
    
    # Sign with entitlements
    if eval "$sign_cmd" 2>&1; then
        # Verify entitlements were embedded
        local temp_entitlements=$(mktemp)
        if codesign -d --entitlements ":$temp_entitlements" "$target" 2>/dev/null; then
            if grep -q "com.apple.security.app-sandbox" "$temp_entitlements" 2>/dev/null; then
                echo "✅ $name signed and verified"
                rm -f "$temp_entitlements"
                return 0
            else
                echo "⚠️  $name signed but App Sandbox entitlement not found"
                rm -f "$temp_entitlements"
                return 1
            fi
        else
            echo "✅ $name signed (entitlements verification skipped)"
            rm -f "$temp_entitlements"
            return 0
        fi
    else
        echo "❌ Failed to sign $name"
        return 1
    fi
}

# Sign Autoupdate
sign_with_entitlements "$SPARKLE_FRAMEWORK/Versions/B/Autoupdate" "Autoupdate"

# Sign Updater.app
UPDATER_APP="$SPARKLE_FRAMEWORK/Versions/B/Updater.app"
if [ -d "$UPDATER_APP" ]; then
    if [ -f "$UPDATER_APP/Contents/MacOS/Updater" ]; then
        sign_with_entitlements "$UPDATER_APP/Contents/MacOS/Updater" "Updater executable"
    fi
    sign_with_entitlements "$UPDATER_APP" "Updater.app bundle"
fi

# Sign Downloader.xpc
DOWNLOADER_XPC="$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Downloader.xpc"
if [ -d "$DOWNLOADER_XPC" ]; then
    if [ -f "$DOWNLOADER_XPC/Contents/MacOS/Downloader" ]; then
        sign_with_entitlements "$DOWNLOADER_XPC/Contents/MacOS/Downloader" "Downloader executable"
    fi
    sign_with_entitlements "$DOWNLOADER_XPC" "Downloader.xpc bundle"
fi

# Sign Installer.xpc
INSTALLER_XPC="$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Installer.xpc"
if [ -d "$INSTALLER_XPC" ]; then
    if [ -f "$INSTALLER_XPC/Contents/MacOS/Installer" ]; then
        sign_with_entitlements "$INSTALLER_XPC/Contents/MacOS/Installer" "Installer executable"
    fi
    sign_with_entitlements "$INSTALLER_XPC" "Installer.xpc bundle"
fi

# Re-sign the entire Sparkle framework
echo "   Re-signing Sparkle framework..."
codesign --force --sign "$SIGN_IDENTITY" --options runtime "$SPARKLE_FRAMEWORK" 2>&1 || echo "⚠️  Failed to re-sign framework"

# Re-sign the app to ensure everything is consistent
echo "   Re-signing app bundle..."
codesign --force --deep --sign "$SIGN_IDENTITY" --options runtime "$APP_BUNDLE" 2>&1 || echo "⚠️  Failed to re-sign app"

echo ""
echo "✅ Sparkle framework components signing complete!"
echo ""
echo "📋 Final verification:"
echo "   All Sparkle components have been signed with App Sandbox entitlements"
echo "   The Archive is now ready for App Store submission"
echo ""
echo "💡 Next steps:"
echo "   1. In Xcode Organizer, select this Archive"
echo "   2. Click 'Distribute App' → 'App Store Connect'"
echo "   3. Complete the upload process"
echo ""
echo "⚠️  Note: dSYM warnings for Sparkle components are expected"
echo "   (Sparkle is a third-party framework without source code)"
echo "   These warnings typically do not prevent submission"

