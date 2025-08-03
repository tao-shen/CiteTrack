#!/bin/bash

# Test script for iCloud debugging
# This will rebuild the app with new debug logging and run it briefly to see the iCloud status

cd "$(dirname "$0")/.."

echo "🔍 Testing iCloud Debug Implementation..."

# Build the app with the new debug logging
echo "🔨 Building app with iCloud debug logging..."
./scripts/build_charts.sh

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo ""
echo "🚀 Running app to check iCloud status..."
echo "Note: Look for debug output starting with 🔍 [iCloud Debug]"
echo "The app will run for 10 seconds to capture startup logs, then exit."
echo ""

# Run the app in background and capture output
timeout 10s ./CiteTrack.app/Contents/MacOS/CiteTrack 2>&1 | grep -E "(🔍|🚀|❌|✅)" || echo "No debug output captured - check if app is running correctly"

echo ""
echo "🔍 Test completed. Check the output above for iCloud status information."
echo ""
echo "Key things to look for:"
echo "  - Whether iCloud account token exists"
echo "  - Whether container URLs are available (nil vs actual URLs)"
echo "  - Whether directories are accessible"
echo "  - Any permission errors"
echo ""
echo "If you see 'iCloud container URL is nil', this indicates missing entitlements."
echo "If you see permission errors, this indicates App Sandbox restrictions."