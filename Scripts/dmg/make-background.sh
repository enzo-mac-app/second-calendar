#!/bin/sh
# Renders background.html to background.tiff (640×420 at 1x and 2x in one file, so Finder picks the sharp
# one on Retina). Needs Google Chrome. Only rerun after editing background.html; the .tiff is committed.
set -e
cd "$(dirname "$0")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
TMP=$(mktemp -d)
for s in 1 2; do
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --force-device-scale-factor=$s --window-size=640,420 --screenshot="$TMP/bg$s.png" \
    "file://$PWD/background.html" >/dev/null 2>&1
done
sips -s dpiWidth 144 -s dpiHeight 144 "$TMP/bg2.png" >/dev/null
tiffutil -cathidpicheck "$TMP/bg1.png" "$TMP/bg2.png" -out background.tiff >/dev/null
rm -rf "$TMP"
echo "wrote background.tiff"
