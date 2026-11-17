#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Quit gracefully and wait for the old instance to release its local socket.
osascript <<'APPLESCRIPT'
if application id "us.tahsin.shelferry" is running then
    tell application id "us.tahsin.shelferry" to quit
    repeat 100 times
        if application id "us.tahsin.shelferry" is not running then exit repeat
        delay 0.1
    end repeat
    if application id "us.tahsin.shelferry" is running then
        error "Shelferry is still running. Quit it manually, then run make dev again."
    end if
end if
APPLESCRIPT

open "$PWD/build/Shelferry.app"
