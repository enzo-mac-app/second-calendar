#!/bin/bash
# Renders the drop-down in each language into docs/ui/ (sample events, no calendar access needed).
#   Scripts/snapshot.sh [day]     day defaults to today, e.g. 2026-10-01
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --product SecondCalendarApp >/dev/null
BIN="$(swift build --show-bin-path)/SecondCalendarApp"
DAY="${1:-$(date +%F)}"
mkdir -p docs/ui
"$BIN" --snapshot docs/ui/popover-zh.png --day "$DAY" -language zh -primaryRegion cn -firstWeekday 2
"$BIN" --snapshot docs/ui/popover-zh-dark.png --day "$DAY" --dark -language zh -primaryRegion cn -firstWeekday 2
"$BIN" --snapshot docs/ui/popover-en.png --day "$DAY" -language en -primaryRegion us -firstWeekday 1
"$BIN" --snapshot docs/ui/popover-ja.png --day "$DAY" -language ja -primaryRegion jp -firstWeekday 1
"$BIN" --snapshot docs/ui/popover-zh-national-day.png --day 2026-10-01 -language zh -primaryRegion cn -firstWeekday 2
