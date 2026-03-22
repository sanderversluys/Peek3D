#!/bin/bash
set -euo pipefail

APP_NAME="Peek3D"
SCHEME="Peek3D"
TEAM_ID="T8CL6FL5T7"
KEYCHAIN_PROFILE="Peek3D"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
DMG_PATH="$BUILD_DIR/Peek3D.dmg"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() { echo -e "\n${GREEN}==> $1${NC}"; }
warn() { echo -e "${YELLOW}$1${NC}"; }

# Check keychain profile exists
if ! xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" &>/dev/null; then
    warn "No notarytool keychain profile '$KEYCHAIN_PROFILE' found."
    echo "Set one up (one-time):"
    echo ""
    echo "  xcrun notarytool store-credentials \"$KEYCHAIN_PROFILE\" \\"
    echo "    --apple-id YOUR_APPLE_ID@EMAIL \\"
    echo "    --team-id $TEAM_ID"
    echo ""
    echo "You'll be prompted for an app-specific password."
    echo "Generate one at https://appleid.apple.com/account/manage → App-Specific Passwords"
    exit 1
fi

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Regenerate project (in case project.yml changed)
step "Generating Xcode project..."
xcodegen generate

# Archive
step "Archiving..."
xcodebuild archive \
    -project "Peek3D.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Manual \
    | tail -3

# Export
step "Exporting..."
cat > "$BUILD_DIR/ExportOptions.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>T8CL6FL5T7</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -exportPath "$EXPORT_PATH" \
    | tail -3

# Create ZIP for notarization
step "Creating ZIP..."
cd "$EXPORT_PATH"
zip -r "../Peek3D.zip" "$APP_NAME.app"
cd - > /dev/null

# Notarize
step "Submitting for notarization..."
xcrun notarytool submit "$BUILD_DIR/Peek3D.zip" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

# Staple
step "Stapling ticket..."
xcrun stapler staple "$EXPORT_PATH/$APP_NAME.app"

# Create DMG
step "Creating DMG..."
hdiutil create -volname "Peek3D" \
    -srcfolder "$EXPORT_PATH/$APP_NAME.app" \
    -ov -format UDZO \
    "$DMG_PATH"

# Notarize DMG too
step "Notarizing DMG..."
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

xcrun stapler staple "$DMG_PATH"

step "Done!"
echo ""
echo "Artifacts:"
echo "  $BUILD_DIR/Peek3D.zip  (for GitHub Release)"
echo "  $DMG_PATH              (for direct download)"
echo ""
echo "Upload to GitHub:"
echo "  gh release create v1.0.0 $BUILD_DIR/Peek3D.zip $DMG_PATH --title 'Peek3D v1.0.0' --notes 'Initial release'"
