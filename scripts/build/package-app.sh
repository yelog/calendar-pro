#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
APP_NAME="CalendarPro"
BUNDLE_ID="com.yelog.CalendarPro"
SCHEME="CalendarPro"
PROJECT="$REPO_ROOT/CalendarPro.xcodeproj"

# Sparkle EdDSA public key for update verification
SU_PUBLIC_ED_KEY="JNs4xFnQyC/ctt66ecoECywufBn0Q0/RiBgDFc9qeek="

# Determine version from git tag, fallback to "0.0.0-dev"
VERSION="${VERSION:-$(git -C "$REPO_ROOT" describe --tags --abbrev=0 2>/dev/null || echo "0.0.0-dev")}"
VERSION="${VERSION#v}"  # strip leading 'v'

# Calculate numeric bundle version for Sparkle ordering:
# - Stable: 1.3.2 -> 13299 (base + 99, higher than any pre-release)
# - Beta:   1.3.1-beta.3 -> 13103 (base + pre-release number)
# - Alpha:  1.3.1-alpha.3 -> 13100 (base + 0 offset)
# - RC:     1.3.1-rc.3 -> 13193 (base + 90 offset)
BASE_VERSION=$(echo "$VERSION" | sed -E 's/([0-9]+)\.([0-9]+)\.([0-9]+).*/\1\2\3/')
if [[ "$VERSION" =~ -(alpha|beta|rc)\.?([0-9]+) ]]; then
    PRERELEASE_TYPE="${BASH_REMATCH[1]}"
    PRERELEASE_NUM="${BASH_REMATCH[2]:-0}"
    case "$PRERELEASE_TYPE" in
        alpha) OFFSET=0 ;;
        beta)  OFFSET=0 ;;
        rc)    OFFSET=90 ;;
        *)     OFFSET=0 ;;
    esac
    BUNDLE_VERSION="${BASE_VERSION}$(printf "%02d" $((OFFSET + PRERELEASE_NUM)))"
else
    BUNDLE_VERSION="${BASE_VERSION}99"
fi
BUNDLE_VERSION=${BUNDLE_VERSION:-1}

echo "==> Building $APP_NAME $VERSION (universal binary, CFBundleVersion=$BUNDLE_VERSION)"

# Step 1: Clean previous builds
echo "==> Cleaning previous build artifacts"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

ARCHIVE_PATH="$DIST_DIR/$APP_NAME.xcarchive"

# Step 2: Resolve SPM dependencies
echo "==> Resolving Swift Package dependencies"
xcodebuild -resolvePackageDependencies \
    -project "$PROJECT" \
    -scheme "$SCHEME" 2>&1 | tail -5

# Step 3: Build universal binary via xcodebuild archive
echo "==> xcodebuild archive (arm64 + x86_64)"
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUNDLE_VERSION" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    | xcbeautify 2>/dev/null || true

# Verify archive was created
if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "ERROR: Archive not found at $ARCHIVE_PATH"
    echo "==> Retrying without xcbeautify..."
    xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -destination "generic/platform=macOS" \
        ARCHS="arm64 x86_64" \
        ONLY_ACTIVE_ARCH=NO \
        MARKETING_VERSION="$VERSION" \
        CURRENT_PROJECT_VERSION="$BUNDLE_VERSION" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO
fi

APP_DIR="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
if [ ! -d "$APP_DIR" ]; then
    echo "ERROR: App bundle not found at $APP_DIR"
    exit 1
fi

echo "==> Archive created at $ARCHIVE_PATH"

# Step 4: Inject Sparkle SUPublicEDKey into Info.plist
PLIST_PATH="$APP_DIR/Contents/Info.plist"
echo "==> Injecting SUPublicEDKey into Info.plist"
/usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SU_PUBLIC_ED_KEY" "$PLIST_PATH" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $SU_PUBLIC_ED_KEY" "$PLIST_PATH"
echo "==> SUPublicEDKey set in Info.plist"

# Verify Sparkle.framework is embedded
if [ -d "$APP_DIR/Contents/Frameworks/Sparkle.framework" ]; then
    echo "==> Sparkle.framework found in app bundle"
else
    echo "WARNING: Sparkle.framework NOT found in app bundle - auto-update will not work"
fi

# Step 5: Copy .app to dist for signing
DIST_APP="$DIST_DIR/$APP_NAME.app"
cp -R "$APP_DIR" "$DIST_APP"
echo "==> App bundle copied to $DIST_APP"

# Step 6: Ad-hoc sign bundle for local distribution
echo "==> Ad-hoc signing app bundle"
codesign --force --deep \
    --sign - \
    --timestamp=none \
    --identifier "$BUNDLE_ID" \
    "$DIST_APP"
codesign --verify --verbose=2 "$DIST_APP"
echo "==> Ad-hoc signing complete"

# Step 7: Code sign the .app bundle (CI only, must happen BEFORE creating DMG)
if [ "${CODESIGN_ENABLED:-}" = "1" ]; then
    echo "==> Running code signing on .app bundle..."
    bash "$SCRIPT_DIR/codesign-and-notarize.sh" sign "$DIST_APP"
else
    echo "==> Skipping code signing (set CODESIGN_ENABLED=1 to enable)"
fi

# Step 8: Package as .dmg (from the signed .app)
DMG_NAME="${APP_NAME}-${VERSION}-universal.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
DMG_STAGING="$DIST_DIR/.dmg-staging"

rm -f "$DMG_PATH"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

# Stage .app and /Applications symlink for drag-to-install
cp -R "$DIST_APP" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

echo "==> Creating $DMG_NAME"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_STAGING"

echo "==> DMG created at: $DMG_PATH"

# Step 9: Sign DMG and notarize (CI only)
if [ "${CODESIGN_ENABLED:-}" = "1" ]; then
    echo "==> Signing DMG and submitting for notarization..."
    bash "$SCRIPT_DIR/codesign-and-notarize.sh" notarize "$DMG_PATH"
fi

# Step 10: Compute SHA-256 (must be after signing, since stapler modifies the DMG)
SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
echo "$SHA256  $DMG_NAME" > "$DIST_DIR/$DMG_NAME.sha256"
echo "==> SHA-256: $SHA256"

# Cleanup archive
rm -rf "$ARCHIVE_PATH"

echo ""
echo "Done! Output:"
echo "  $DMG_PATH"
echo "  $DIST_DIR/$DMG_NAME.sha256"
