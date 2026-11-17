#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command="${1:?Expected build or test}"
shift
sdk="$(bash scripts/select-macos-sdk.sh)"
args=(--sdk "$sdk")
if [[ "$sdk" != "$(xcrun --sdk macosx --show-sdk-path)" ]]; then
  args+=(--scratch-path .build/compatible-sdk --disable-experimental-prebuilts)
fi
exec swift "$command" "${args[@]}" "$@"
