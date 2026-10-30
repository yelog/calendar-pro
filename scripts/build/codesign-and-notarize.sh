#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENTITLEMENTS="$REPO_ROOT/CalendarPro/CalendarPro.entitlements"

# ─── Resolve signing identity ───
resolve_identity() {
    echo "==> Available signing identities:"
    security find-identity -v -p codesigning
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')

    if [ -z "$SIGNING_IDENTITY" ]; then
        echo "ERROR: No Developer ID Application certificate found in keychain"
        exit 1
    fi
    echo "==> Using identity: $SIGNING_IDENTITY"
}

# Apple ticket delivery occasionally fails on a transient CloudKit network error.
# Retry those failures so a successful notarization is not wasted on one dropped request.
stapler_with_retry() {
    local ACTION="${1:?Usage: stapler_with_retry <staple|validate> <path> }"
    local TARGET="${2:?Usage: stapler_with_retry <staple|validate> <path> }"
    local MAX_ATTEMPTS=5
    local ATTEMPT=1
    local DELAY=2
    local OUTPUT
    local STATUS

    while [ "$ATTEMPT" -le "$MAX_ATTEMPTS" ]; do
        echo "==> Running stapler $ACTION (attempt $ATTEMPT/$MAX_ATTEMPTS)"
        if OUTPUT=$(xcrun stapler "$ACTION" "$TARGET" 2>&1); then
            echo "$OUTPUT"
            return 0
        else
            STATUS=$?
        fi

        echo "$OUTPUT"
        if [[ "$OUTPUT" != *"Error 68"* && "$OUTPUT" != *"NSURLErrorDomain"* && "$OUTPUT" != *"CloudKit's response is inconsistent"* ]]; then
            echo "ERROR: stapler $ACTION failed with a non-retryable error (exit $STATUS)"
            return "$STATUS"
        fi

        if [ "$ATTEMPT" -eq "$MAX_ATTEMPTS" ]; then
            echo "ERROR: stapler $ACTION failed after $MAX_ATTEMPTS attempts"
            return "$STATUS"
        fi

        echo "==> Transient ticket delivery error; retrying in ${DELAY}s"
        sleep "$DELAY"
        DELAY=$((DELAY * 2))
        ATTEMPT=$((ATTEMPT + 1))
    done
}

# ─── Command: sign ───
# Signs the .app bundle (must run BEFORE creating DMG)
cmd_sign() {
    local APP_DIR="${1:?Usage: $0 sign <path-to-app>}"
    resolve_identity

    # Sign embedded frameworks first (inside-out order)
    if [ -d "$APP_DIR/Contents/Frameworks/Sparkle.framework" ]; then
        echo "==> Signing embedded framework: Sparkle"
        codesign --force --deep --options runtime \
            --sign "$SIGNING_IDENTITY" \
            --timestamp \
            "$APP_DIR/Contents/Frameworks/Sparkle.framework"
    fi

    # Sign the main app bundle
    echo "==> Signing main app bundle"
    codesign --force --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --sign "$SIGNING_IDENTITY" \
        --timestamp \
        "$APP_DIR"

    # Verify
    echo "==> Verifying signature..."
    codesign --verify --verbose=2 "$APP_DIR"
    echo "==> App bundle signed successfully"
}

# ─── Command: notarize ───
# Signs the DMG, submits for notarization, and staples the ticket
cmd_notarize() {
    local DMG_PATH="${1:?Usage: $0 notarize <path-to-dmg>}"

    : "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"
    : "${APPLE_ID:?APPLE_ID is required}"
    : "${APPLE_APP_PASSWORD:?APPLE_APP_PASSWORD is required}"

    resolve_identity

    # Sign the DMG
    echo "==> Signing DMG"
    codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"

    # Submit for notarization
    echo "==> Submitting for notarization (this may take several minutes)..."
    NOTARY_OUTPUT=$(xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_APP_PASSWORD" \
        --team-id "$APPLE_TEAM_ID" \
        --wait \
        --timeout 30m 2>&1) || true

    echo "$NOTARY_OUTPUT"

    # Extract submission ID and check status
    SUBMISSION_ID=$(echo "$NOTARY_OUTPUT" | grep "id:" | head -1 | awk '{print $2}')
    NOTARY_STATUS=$(echo "$NOTARY_OUTPUT" | grep "status:" | tail -1 | awk '{print $2}')

    if [ "$NOTARY_STATUS" != "Accepted" ]; then
        echo "==> Notarization failed with status: $NOTARY_STATUS"
        if [ -n "$SUBMISSION_ID" ]; then
            echo "==> Fetching notarization log for submission: $SUBMISSION_ID"
            xcrun notarytool log "$SUBMISSION_ID" \
                --apple-id "$APPLE_ID" \
                --password "$APPLE_APP_PASSWORD" \
                --team-id "$APPLE_TEAM_ID" || true
        fi
        exit 1
    fi

    # Staple notarization ticket
    echo "==> Stapling notarization ticket to DMG"
    stapler_with_retry staple "$DMG_PATH"
    stapler_with_retry validate "$DMG_PATH"

    echo "==> Notarization complete!"
}

# ─── Dispatch ───
COMMAND="${1:?Usage: $0 <sign|notarize> <path>}"
shift
case "$COMMAND" in
    sign)     cmd_sign "$@" ;;
    notarize) cmd_notarize "$@" ;;
    *)        echo "Unknown command: $COMMAND"; exit 1 ;;
esac
