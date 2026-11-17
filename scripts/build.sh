#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${CONFIGURATION:-release}"
version="${VERSION:-0.1.0}"
architecture="${ARCHS:-$(uname -m)}"
args=()
for arch in $architecture; do args+=(--arch "$arch"); done
bash scripts/swift.sh build -c "$configuration" "${args[@]}"
bin="$(bash scripts/swift.sh build -c "$configuration" "${args[@]}" --show-bin-path)"
app=build/Shelferry.app
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Helpers"
cp "$bin/Shelferry" "$app/Contents/MacOS/Shelferry"
cp "$bin/ShelferryCommand" "$app/Contents/Helpers/shelferry"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER:-1}" "$app/Contents/Info.plist"
if [[ -f Resources/AppIcon.icns ]]; then cp Resources/AppIcon.icns "$app/Contents/Resources/"; fi
# SwiftPM dependency resource bundles are looked up beside the executable.
for resource in "$bin"/*.bundle; do
  [[ -d "$resource" ]] && ditto "$resource" "$app/Contents/MacOS/$(basename "$resource")"
done
cp Resources/ThirdPartyNotices.txt "$app/Contents/Resources/"
codesign --force --sign "${SIGN_ID:--}" "$app/Contents/Helpers/shelferry"
codesign --force --sign "${SIGN_ID:--}" "$app"
codesign --verify --deep --strict "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" build/Shelferry.zip
shasum -a 256 build/Shelferry.zip > build/Shelferry.zip.sha256
