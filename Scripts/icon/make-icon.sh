#!/bin/bash
# Renders the app icon into Scripts/icon/SecondCalendar.icns and Scripts/icon/icon-1024.png (both committed).
set -euo pipefail
cd "$(dirname "$0")"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
swiftc -O draw-icon.swift -o "$TMP/draw" 2>/dev/null
rm -rf "$TMP/SecondCalendar.iconset"; mkdir "$TMP/SecondCalendar.iconset"
for n in 16 32 128 256 512; do
    "$TMP/draw" $n "$TMP/SecondCalendar.iconset/icon_${n}x${n}.png"
    "$TMP/draw" $((n * 2)) "$TMP/SecondCalendar.iconset/icon_${n}x${n}@2x.png"
done
iconutil -c icns "$TMP/SecondCalendar.iconset" -o SecondCalendar.icns
"$TMP/draw" 1024 icon-1024.png
echo "icon → Scripts/icon/SecondCalendar.icns"
