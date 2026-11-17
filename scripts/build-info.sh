#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

app=build/Shelferry.app
plist="$app/Contents/Info.plist"
executable="$app/Contents/MacOS/Shelferry"
archive=build/Shelferry.zip

if [[ ! -f "$plist" || ! -f "$executable" ]]; then
  printf 'No complete build found. Run make dev or make app first.\n' >&2
  exit 1
fi

field() {
  printf '%-22s %s\n' "$1:" "$2"
}

metadata() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$plist" 2>/dev/null || printf 'unknown'
}

format_size() {
  awk -v bytes="$1" 'BEGIN { printf "%.2f MiB (%d bytes)", bytes / 1048576, bytes }'
}

field "App" "$app"
field "Version" "$(metadata CFBundleShortVersionString) (build $(metadata CFBundleVersion))"
field "Channel" "$(metadata ShelferryBuildChannel)"
field "Configuration" "$(metadata ShelferryBuildConfiguration)"
field "Architecture" "$(lipo -archs "$executable")"
field "Minimum macOS" "$(metadata LSMinimumSystemVersion)"
sdk_versions=$(xcrun vtool -show-build "$executable" | awk '$1 == "sdk" && !seen[$2]++ { if (count++) printf ", "; printf "%s", $2 }')
field "SDK version" "${sdk_versions:-unknown}"

# du reports allocated disk space; individual files use their actual byte length.
app_kib=$(du -sk "$app" | awk '{print $1}')
field "App size on disk" "$(format_size "$((app_kib * 1024))")"
field "Executable size" "$(format_size "$(stat -f %z "$executable")")"
if [[ -f "$archive" ]]; then
  field "ZIP size" "$(format_size "$(stat -f %z "$archive")")"
else
  field "ZIP size" "not available"
fi

if codesign --verify --deep --strict "$app" 2>/dev/null; then
  signature=$(codesign -dv "$app" 2>&1)
  if [[ "$signature" == *"Signature=adhoc"* ]]; then
    field "Signing" "valid (ad hoc)"
  else
    field "Signing" "valid"
  fi
else
  field "Signing" "unsigned or invalid"
fi
