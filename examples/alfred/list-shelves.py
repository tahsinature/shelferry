#!/usr/bin/env python3
import json
import os
import shutil
import subprocess

candidates = [os.environ.get("SHELFERRY_BIN", "shelferry"), "/opt/homebrew/bin/shelferry", "/usr/local/bin/shelferry", "/Applications/Shelferry.app/Contents/Helpers/shelferry"]
try:
    binary = next((shutil.which(path) for path in candidates if shutil.which(path)), None)
    if not binary:
        raise RuntimeError("Install Shelferry or set SHELFERRY_BIN")
    result = subprocess.run([binary, "list", "--json"], capture_output=True, text=True, timeout=15)
    response = json.loads(result.stdout)
    if result.returncode:
        raise RuntimeError(response.get("error", result.stderr))
    items = [{"uid": shelf["id"], "title": shelf["name"], "subtitle": f'{shelf["count"]} items', "arg": shelf["id"]} for shelf in response["shelves"]]
    print(json.dumps({"items": items or [{"title": "No shelves yet", "valid": False}]}))
except Exception as error:
    print(json.dumps({"items": [{"title": "Shelferry unavailable", "subtitle": str(error), "valid": False}]}))
