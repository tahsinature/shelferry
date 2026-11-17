#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Toggle Shelferry
# @raycast.mode silent
# @raycast.packageName Shelferry
set -euo pipefail
for binary in "${SHELFERRY_BIN:-shelferry}" /opt/homebrew/bin/shelferry /usr/local/bin/shelferry /Applications/Shelferry.app/Contents/Helpers/shelferry; do
  if command -v "$binary" >/dev/null 2>&1; then exec "$binary" toggle; fi
done
echo "Install Shelferry or set SHELFERRY_BIN." >&2
exit 1
