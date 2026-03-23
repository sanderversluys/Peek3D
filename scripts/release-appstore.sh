#!/bin/bash
set -euo pipefail

SCHEME="Peek3D"
TEAM_ID="T8CL6FL5T7"
BUILD_DIR="build-appstore"
ARCHIVE_PATH="$BUILD_DIR/Peek3D.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"

# Provisioning profile UUIDs
PROFILE_APP="64109a70-fee5-4708-98ec-d4f6a5bc29b5"
PROFILE_PREVIEW="161ab238-64b6-4bc4-8a85-abebd5a367bd"
PROFILE_THUMBNAIL="14c4a72f-1dfa-406e-998d-995e3a2baa9d"

GREEN='\033[0;32m'
NC='\033[0m'
step() { echo -e "\n${GREEN}==> $1${NC}"; }

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Regenerate project
step "Generating Xcode project..."
xcodegen generate

# Archive with Apple Distribution signing
step "Archiving..."
xcodebuild archive \
    -project "Peek3D.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="Apple Distribution" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Manual \
    | tail -3

# Export for App Store
step "Exporting for App Store..."
cat > "$BUILD_DIR/ExportOptions.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>T8CL6FL5T7</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>3rd Party Mac Developer Application</string>
    <key>installerSigningCertificate</key>
    <string>3rd Party Mac Developer Installer</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>com.sanderversluys.Peek3D</key>
        <string>64109a70-fee5-4708-98ec-d4f6a5bc29b5</string>
        <key>com.sanderversluys.Peek3D.PreviewExtension</key>
        <string>161ab238-64b6-4bc4-8a85-abebd5a367bd</string>
        <key>com.sanderversluys.Peek3D.ThumbnailExtension</key>
        <string>14c4a72f-1dfa-406e-998d-995e3a2baa9d</string>
    </dict>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -exportPath "$EXPORT_PATH" \
    | tail -3

step "Done!"
echo ""
echo "Upload to App Store Connect:"
echo "  1. Open Transporter (install from Mac App Store if needed)"
echo "  2. Drag in the .pkg from: $EXPORT_PATH/"
echo "  3. Click Deliver"
echo ""
echo "Then go to appstoreconnect.apple.com to submit for review."
