#!/bin/bash
# Makes the installer DMG: a Finder window with the drag-to-Applications background (background.tiff),
# Second Calendar on the left, an Applications shortcut on the right, and the app icon as the volume icon.
#   Scripts/dmg/make-dmg.sh "build/Second Calendar.app" build/SecondCalendar-1.0.0.dmg
# Lays out the window through Finder, so it must run in a logged-in session (the first run asks to let
# the terminal control Finder). Signing and notarizing the result is up to the caller.
set -euo pipefail
APP=$1; OUT=$2
HERE=$(cd "$(dirname "$0")" && pwd)
NAME="Second Calendar"
TMP_SAFE=SecondCalendar
# Laid out under a unique volume name, so Finder never confuses it with a Second Calendar DMG that is already
# mounted (say, the last release in Downloads); renamed to "Second Calendar" just before it is closed.
TMPNAME="$TMP_SAFE-build-$$"
WORK=$(mktemp -d)
DEV=
trap '[ -n "$DEV" ] && hdiutil detach "$DEV" -force >/dev/null 2>&1; rm -rf "$WORK"' EXIT

mkdir -p "$WORK/stage/.background" "$WORK/mnt"
cp -R "$APP" "$WORK/stage/"
ln -s /Applications "$WORK/stage/Applications"
cp "$HERE/background.tiff" "$WORK/stage/.background/background.tiff"
cp "$APP/Contents/Resources/SecondCalendar.icns" "$WORK/stage/.VolumeIcon.icns" 2>/dev/null || true

hdiutil create -volname "$TMPNAME" -srcfolder "$WORK/stage" -fs HFS+ -format UDRW -ov "$WORK/rw.dmg" >/dev/null
DEV=$(hdiutil attach "$WORK/rw.dmg" -readwrite -noverify -noautoopen -mountroot "$WORK/mnt" | awk 'NR==1{print $1}')
VOL="$WORK/mnt/$TMPNAME"
[ -f "$VOL/.VolumeIcon.icns" ] && SetFile -a C "$VOL"
# Hidden even for people who show hidden files in Finder would be ideal, but the flag is what Finder honours.
rm -rf "$VOL/.fseventsd"
chflags hidden "$VOL/.background" "$VOL/.VolumeIcon.icns" 2>/dev/null || true

# Window 640×420 content (plus the title bar). Finder draws an icon about 35 pt below the position it is
# given, so y=150 here lands the icons on the arrow ends in background.html (y≈185).
osascript <<OSA
tell application "Finder"
  set d to (POSIX file "$VOL" as alias)
  open d
  delay 2
  set w to container window of d
  set current view of w to icon view
  set toolbar visible of w to false
  set statusbar visible of w to false
  set bounds of w to {200, 120, 840, 568}
  set o to icon view options of w
  set arrangement of o to not arranged
  set icon size of o to 112
  set text size of o to 13
  set background picture of o to (POSIX file "$VOL/.background/background.tiff" as alias)
  set position of item "$NAME.app" of d to {170, 150}
  set position of item "Applications" of d to {470, 150}
  close w
  open d
  delay 1
  close container window of d
end tell
OSA
rm -rf "$VOL/.fseventsd" "$VOL/.Trashes"
sync
diskutil rename "$VOL" "$NAME" >/dev/null
hdiutil detach "$DEV" >/dev/null
DEV=
rm -f "$OUT"
# ULMO (LZMA, macOS 10.15+): smallest download; Cloudflare Pages serves files up to 25 MiB.
hdiutil convert "$WORK/rw.dmg" -format ULMO -o "$OUT" >/dev/null
echo "made $OUT"
