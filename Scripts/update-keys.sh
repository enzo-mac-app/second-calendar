#!/bin/bash
# Makes the key pair that signs updates. Run once, on the Mac that builds releases.
#
# The private key goes into the login keychain (Sparkle's generate_keys keeps it there, account
# "secondcalendar") and never leaves it. The public key is written to Scripts/sparkle-public-key,
# which is committed: every copy of the app carries it and only installs updates signed with the
# private key.
#
# Losing the private key means existing copies can never auto-update again. Back it up:
#   .build/artifacts/sparkle/Sparkle/bin/generate_keys --account secondcalendar -x ~/secondcalendar-sparkle-private-key
# and keep that file somewhere safe (a password manager), never in this repository.
set -euo pipefail
cd "$(dirname "$0")/.."
BIN=.build/artifacts/sparkle/Sparkle/bin
[ -x "$BIN/generate_keys" ] || swift package resolve
"$BIN/generate_keys" --account secondcalendar >/dev/null
"$BIN/generate_keys" --account secondcalendar -p > Scripts/sparkle-public-key
echo "Public key saved to Scripts/sparkle-public-key: $(cat Scripts/sparkle-public-key)"
echo "Commit that file. Then back up the private key (see the top of this script)."
