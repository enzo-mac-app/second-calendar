#!/bin/bash
# Regenerates the data behind the website's in-browser calendar (enzomac.app/cal/)
# from CalendarCore, into the site repo. Run after Scripts/update-holidays.sh or a holiday fix, then deploy the site.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-../tidygrid/site/public-secondcalendar/assets/calendar-data.json}"
swift run -c release sc-webdata "$OUT"
