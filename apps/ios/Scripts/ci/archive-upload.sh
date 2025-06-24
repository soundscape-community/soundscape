#!/bin/zsh
# This script archives the app and uploads it to App Store Connect.
# It can be run interactively or in a CI environment.
# In a CI environment:
# - the developer certificate should be in a keychain called signing_temp.keychain-db
# - it will use the keychain password from the environment variable KEYCHAIN_PASSWORD.
# - the appstore authentication key should be  base64 encoded in $APPSTORE_CONNECT_API_KEY
# the Appstore key id is $APPSTORE_CONNECT_KEY_ID
# - the appstore issuer id is $APPSTORE_CONNECT_ISSUER_ID
set -e

SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
APP_PROJECT="$SCRIPTDIR/../../GuideDogs.xcodeproj"
APP_SCHEME=Soundscape
APP_ARCHIVE_PATH="$SCRIPTDIR/build/$APP_SCHEME.xcarchive"
EXTRA_ARGS=()
if [ -t 0 ]; then
# if stdin is a terminal, then we are running interactively
    export APP_KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
    security unlock-keychain  "$HOME/Library/Keychains/login.keychain-db"
else
    # we are running in CI
    export APP_KEYCHAIN="$HOME/Library/Keychains/signing_temp.keychain-db"
    if [ -z "$KEYCHAIN_PASSWORD" ]; then
        echo "Error: KEYCHAIN_PASSWORD is not set." >&2
        exit 1
    fi
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$APP_KEYCHAIN"
    security default-keychain -s "$APP_KEYCHAIN"
    authenticationKeyPath="$(mktemp)"
    echo "$APPSTORE_CONNECT_API_KEY" | base64 --decode > "$authenticationKeyPath"
    # clean up the key after use
    trap 'rm -f "$authenticationKeyPath"' EXIT
    EXTRA_ARGS=(
        -authenticationKeyPath "$authenticationKeyPath"
        -authenticationKeyID "$APPSTORE_CONNECT_KEY_ID"
        -authenticationKeyIssuerID "$APPSTORE_CONNECT_ISSUER_ID"
    )
fi

xcodebuild archive  \
    -project "$APP_PROJECT" \
    -scheme "$APP_SCHEME" \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -allowProvisioningUpdates \
    -archivePath "$APP_ARCHIVE_PATH" \
    "${EXTRA_ARGS[@]}" 


# use xcodebuild to export and upload the archive
xcodebuild \
    -exportArchive \
    -archivePath "$APP_ARCHIVE_PATH" \
    -exportOptionsPlist "$SCRIPTDIR/ExportOptions.plist" \
    -exportPath "$SCRIPTDIR/build" \
    -allowProvisioningUpdates \
    "${EXTRA_ARGS[@]}"

