# iCloud Drive Debug Guide

This guide documents the iCloud Drive availability issue in CiteTrack and the debugging solutions implemented.

## Problem Summary

The CiteTrack app was showing iCloud Drive as "not available" even when users were logged into iCloud. This prevented users from syncing their citation data across devices.

## Root Cause Analysis

The original iCloud detection logic in `iCloudSyncManager.swift` was:

```swift
var isiCloudAvailable: Bool {
    return FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
}
```

This simple check fails for several reasons:

1. **Missing iCloud Entitlements**: The app wasn't code-signed with proper iCloud entitlements
2. **App Sandbox Restrictions**: Without proper entitlements, sandboxed apps can't access iCloud containers
3. **Container Identifier Issues**: Using `nil` as the container identifier may not work reliably

## Solutions Implemented

### 1. Created iCloud Entitlements File

**File**: `/CiteTrack.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- iCloud Drive entitlements -->
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.citetrack.app</string>
    </array>
    
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudDocuments</string>
    </array>
    
    <key>com.apple.developer.ubiquity-container-identifiers</key>
    <array>
        <string>iCloud.com.citetrack.app</string>
    </array>
    
    <!-- App Sandbox permissions -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

### 2. Enhanced iCloud Detection Logic

**File**: `/Sources/iCloudSyncManager.swift`

The new detection logic:

1. **Checks iCloud Account Status**: Uses `FileManager.default.ubiquityIdentityToken` to verify user is logged in
2. **Tries Multiple Container Identifiers**: Attempts specific container first, falls back to default
3. **Tests Directory Access**: Actually tries to read the container directory to verify permissions
4. **Creates Missing Folders**: Automatically creates Documents folder if missing
5. **Comprehensive Error Reporting**: Provides detailed diagnostic information

Key improvements:

```swift
var isiCloudAvailable: Bool {
    // Check if user is logged in to iCloud
    let ubiquityToken = FileManager.default.ubiquityIdentityToken
    
    // Try specific container first, then default
    let specificContainerURL = FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerIdentifier)
    let defaultContainerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)
    
    let ubiquityURL = specificContainerURL ?? defaultContainerURL
    
    if let url = ubiquityURL {
        // Actually test directory access
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: url.path)
            return true
        } catch {
            // Log specific permission errors
            return false
        }
    }
    
    return false
}
```

### 3. Updated Build Script

**File**: `/scripts/build_charts.sh`

Modified the code signing section to apply entitlements:

```bash
# Code signing with iCloud entitlements
ENTITLEMENTS_FILE="CiteTrack.entitlements"
if [ -f "${ENTITLEMENTS_FILE}" ]; then
    codesign --force --deep --sign - --entitlements "${ENTITLEMENTS_FILE}" "${APP_BUNDLE}"
else
    codesign --force --deep --sign - "${APP_BUNDLE}"
fi
```

### 4. Comprehensive Diagnostic System

Added diagnostic functions to help troubleshoot iCloud issues:

- `getDiagnosticInfo()`: Returns detailed iCloud status information
- `printDiagnosticInfo()`: Prints formatted diagnostic output
- Automatic diagnostic logging on app startup

### 5. Debug Test Script

**File**: `/scripts/test_icloud_debug.sh`

Created a test script that:
1. Rebuilds the app with debug logging
2. Runs the app briefly to capture iCloud status
3. Provides interpretation of common error patterns

## Debug Output Interpretation

When running the app, look for debug output starting with `🔍 [iCloud Debug]`:

### Successful iCloud Access
```
🔍 [iCloud Debug] iCloud account token: EXISTS
🔍 [iCloud Debug] Specific container (iCloud.com.citetrack.app): file:///.../iCloud.com.citetrack.app/
🔍 [iCloud Debug] Successfully accessed iCloud container directory (3 items)
```

### Missing Entitlements
```
🔍 [iCloud Debug] iCloud account token: EXISTS
🔍 [iCloud Debug] Specific container (iCloud.com.citetrack.app): nil
🔍 [iCloud Debug] Default container (nil): nil
🔍 [iCloud Debug] Possible causes:
🔍 [iCloud Debug] - Missing iCloud entitlements
```

### User Not Logged In
```
🔍 [iCloud Debug] iCloud account token: NOT FOUND
🔍 [iCloud Debug] User is not logged in to iCloud
```

### Permission Errors
```
🔍 [iCloud Debug] Error accessing iCloud container: Operation not permitted
🔍 [iCloud Debug] This might indicate missing entitlements or App Sandbox restrictions
```

## Testing Steps

1. **Run Debug Test**:
   ```bash
   ./scripts/test_icloud_debug.sh
   ```

2. **Check System Preferences**:
   - Go to System Preferences > Apple ID > iCloud
   - Ensure iCloud Drive is enabled
   - Check that the user is logged in

3. **Verify App Entitlements**:
   ```bash
   codesign -d --entitlements - CiteTrack.app
   ```

4. **Test Manual iCloud Access**:
   - Open Finder
   - Go to iCloud Drive
   - Try creating a folder manually

## Common Issues and Solutions

### Issue: "Container URL is nil"
**Cause**: Missing iCloud entitlements or incorrect code signing
**Solution**: Ensure entitlements file is present and applied during code signing

### Issue: "Operation not permitted"
**Cause**: App Sandbox restrictions without proper entitlements
**Solution**: Add file access entitlements to the entitlements file

### Issue: "User not logged in to iCloud"
**Cause**: User hasn't signed in to iCloud on their Mac
**Solution**: User needs to sign in via System Preferences > Apple ID

### Issue: Works in development but not in distribution
**Cause**: Different code signing requirements for distribution
**Solution**: Ensure entitlements are properly applied during distribution build

## Next Steps

If iCloud is still not working after implementing these changes:

1. Check if the app needs to be registered with Apple Developer Portal
2. Verify the iCloud container identifier is properly configured
3. Consider using alternative sync methods (Dropbox, Google Drive, manual export/import)
4. Test with different macOS versions and configurations

## Files Modified

- `/Sources/iCloudSyncManager.swift` - Enhanced detection and diagnostic logic
- `/Sources/main.swift` - Added startup diagnostic logging
- `/scripts/build_charts.sh` - Updated code signing with entitlements
- `/CiteTrack.entitlements` - New entitlements file for iCloud access
- `/scripts/test_icloud_debug.sh` - New test script for debugging

This comprehensive approach should resolve the iCloud Drive availability issues and provide clear diagnostic information for troubleshooting.