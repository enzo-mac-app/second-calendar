#!/bin/bash
# Builds a release DMG: build → sign (Developer ID, hardened runtime) → notarize → staple → appcast.
#
#   VERSION=1.0.0 Scripts/release.sh                  the full release
#   VERSION=1.0.0 Scripts/release.sh --skip-notarize  sign only (a quick local check)
#
# Needs, once:
#   1. A "Developer ID Application" certificate in the login keychain
#      (security find-identity -v -p codesigning).
#   2. Saved notary credentials:
#        xcrun notarytool store-credentials <profile> --apple-id <you> --team-id <TEAMID>
#   3. The update key: Scripts/update-keys.sh.
#
# Settings (environment):
#   DEVELOPER_ID    signing identity; default: the first "Developer ID Application" found
#   NOTARY_PROFILE  notarytool keychain profile; default: tidygrid-notary (Enzomac's shared one)
#   VERSION         marketing version written into the app (required)
#
# Output: build/SecondCalendar-<version>.dmg, copied to build/updates/ with a regenerated, signed
# appcast.xml. The site's deploy script publishes them at https://enzomac.app/secondcalendar/download/
# and /appcast.xml. Keep older DMGs in build/updates/ so the appcast keeps listing them.
set -euo pipefail
cd "$(dirname "$0")/.."

SKIP_NOTARIZE=0
[ "${1:-}" = "--skip-notarize" ] && SKIP_NOTARIZE=1
NOTARY_PROFILE="${NOTARY_PROFILE:-tidygrid-notary}"
: "${VERSION:?set VERSION, e.g. VERSION=1.0.0 Scripts/release.sh}"

IDENTITY="${DEVELOPER_ID:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)}"
if [ -z "$IDENTITY" ]; then
    echo "No Developer ID Application certificate found (see the top of this script)."
    exit 2
fi
echo "Signing as: $IDENTITY"

if [ ! -s Scripts/sparkle-public-key ] && [ -z "${SPARKLE_PUBLIC_KEY:-}" ]; then
    echo "No update key yet: run Scripts/update-keys.sh first, or this release can never update itself."
    exit 2
fi

swift test
VERSION="$VERSION" SIGN_IDENTITY="$IDENTITY" Scripts/make-app.sh
APP="build/Second Calendar.app"

DMG="build/SecondCalendar-$VERSION.dmg"
Scripts/dmg/make-dmg.sh "$APP" "$DMG"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

if [ "$SKIP_NOTARIZE" = 1 ]; then
    echo "Signed, not notarized: $DMG"
    exit 0
fi

xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

# generate_appcast reads every DMG in the folder, signs each with the key in the keychain and
# writes appcast.xml next to them.
mkdir -p build/updates
cp "$DMG" build/updates/
.build/artifacts/sparkle/Sparkle/bin/generate_appcast --account secondcalendar \
    --download-url-prefix "https://enzomac.app/secondcalendar/download/" \
    --link "https://enzomac.app/secondcalendar/" build/updates
echo "Ready: $DMG and build/updates/appcast.xml (publish with the site's deploy script)"
