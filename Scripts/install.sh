#!/bin/bash
# Builds, signs with this Mac's Developer ID (so calendar permission survives rebuilds), copies to
# /Applications and (re)starts it. For enzo's own use; public releases will get a release.sh later.
set -euo pipefail
cd "$(dirname "$0")/.."
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)}"
SIGN_IDENTITY="$IDENTITY" Scripts/make-app.sh
pkill -x SecondCalendar 2>/dev/null && sleep 1 || true
rm -rf "/Applications/Second Calendar.app"
ditto "build/Second Calendar.app" "/Applications/Second Calendar.app"
open "/Applications/Second Calendar.app"
echo "Installed and started /Applications/Second Calendar.app"
