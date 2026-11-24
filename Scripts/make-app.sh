#!/bin/bash
# Builds "build/Second Calendar.app". Adapted from SendSize's (no Sparkle, no licence, no helpers yet).
# - Menu bar only: LSUIElement, so no Dock icon.
# - Calendar access: NSCalendarsFullAccessUsageDescription; the hardened-runtime calendars entitlement
#   in Scripts/SecondCalendar.entitlements when signed for real.
# - SIGN_IDENTITY="Developer ID Application: …" signs with the hardened runtime. Without it the app is
#   signed ad-hoc, which works on this Mac but makes macOS ask for calendar access again after each build.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product SecondCalendarApp
BIN="$(swift build -c release --show-bin-path)"
APP="build/Second Calendar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/SecondCalendarApp" "$APP/Contents/MacOS/SecondCalendar"

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
</dict>
</plist>
PLIST

if [ -n "${SIGN_IDENTITY:-}" ]; then
    codesign --force --timestamp --options runtime --entitlements Scripts/SecondCalendar.entitlements \
        --sign "$SIGN_IDENTITY" "$APP"
    codesign --verify --strict --verbose=2 "$APP"
else
    codesign --force --sign - --entitlements Scripts/SecondCalendar.entitlements "$APP"
fi
echo "Built $APP"
