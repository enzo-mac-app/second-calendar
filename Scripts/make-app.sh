#!/bin/bash
# Builds "build/Second Calendar.app". Adapted from SendSize's (no licence, no helpers).
# - Menu bar only: LSUIElement, so no Dock icon.
# - Calendar access: NSCalendarsFullAccessUsageDescription; the hardened-runtime calendars entitlement
#   in Scripts/SecondCalendar.entitlements when signed for real.
# - SIGN_IDENTITY="Developer ID Application: …" signs with the hardened runtime. Without it the app is
#   signed ad-hoc, which works on this Mac but makes macOS ask for calendar access again after each build.
# - Auto-update (Sparkle) is switched on only when the public update key is known: from
#   SPARKLE_PUBLIC_KEY, or from Scripts/sparkle-public-key (made once by Scripts/update-keys.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product SecondCalendarApp
BIN="$(swift build -c release --show-bin-path)"
APP="build/Second Calendar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN/SecondCalendarApp" "$APP/Contents/MacOS/SecondCalendar"
# Sparkle, keeping its symlinks and nested helpers intact.
ditto "$BIN/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
# The lunar library's resource bundle, if the package has one.
for b in "$BIN"/*.bundle; do [ -d "$b" ] && ditto "$b" "$APP/Contents/Resources/$(basename "$b")"; done

SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-$(cat Scripts/sparkle-public-key 2>/dev/null || true)}"
FEED="${SPARKLE_FEED_URL:-https://enzomac.app/secondcalendar/appcast.xml}"  # override only for local testing
UPDATE_KEYS=""
if [ -n "$SPARKLE_PUBLIC_KEY" ]; then
    UPDATE_KEYS="<key>SUFeedURL</key><string>$FEED</string>
    <key>SUPublicEDKey</key><string>$SPARKLE_PUBLIC_KEY</string>
    <key>SUEnableAutomaticChecks</key><true/>
    <key>SUScheduledCheckInterval</key><integer>86400</integer>
    <key>SUEnableSystemProfiling</key><false/>"
else
    echo "note: no Sparkle public key, so this build won't check for updates"
fi

[ -f Scripts/icon/SecondCalendar.icns ] || Scripts/icon/make-icon.sh
cp Scripts/icon/SecondCalendar.icns "$APP/Contents/Resources/SecondCalendar.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Second Calendar</string>
    <key>CFBundleDisplayName</key><string>Second Calendar</string>
    <key>CFBundleIdentifier</key><string>app.enzomac.secondcalendar</string>
    <key>CFBundleExecutable</key><string>SecondCalendar</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string><string>ja</string></array>
    <key>CFBundleShortVersionString</key><string>${VERSION:-0.1.0}</string>
    <key>CFBundleVersion</key><string>$(git rev-list --count HEAD 2>/dev/null || echo 1)</string>
    <key>CFBundleIconFile</key><string>SecondCalendar</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHumanReadableCopyright</key><string>© 2026 Enzomac</string>
    <key>NSCalendarsFullAccessUsageDescription</key><string>Second Calendar shows your events next to holidays. 显示你的日程。予定を表示します。</string>
    <key>NSCalendarsUsageDescription</key><string>Second Calendar shows your events next to holidays. 显示你的日程。予定を表示します。</string>
    $UPDATE_KEYS
</dict>
</plist>
PLIST

# Inside out: Sparkle's helpers, Sparkle, then the app (only the app gets the calendar entitlement).
if [ -n "${SIGN_IDENTITY:-}" ]; then
    SIGN=(codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY")
else
    SIGN=(codesign --force --sign -)
fi
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
"${SIGN[@]}" "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
"${SIGN[@]}" --preserve-metadata=entitlements "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
"${SIGN[@]}" "$SPARKLE/Versions/B/Autoupdate"
"${SIGN[@]}" "$SPARKLE/Versions/B/Updater.app"
"${SIGN[@]}" "$SPARKLE"
"${SIGN[@]}" --entitlements Scripts/SecondCalendar.entitlements "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
echo "Built $APP"
