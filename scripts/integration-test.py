#!/usr/bin/env python3
"""Real app + CLI integration using disposable data, sockets, and files."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parent.parent
app = root / "build/Shelferry.app/Contents/MacOS/Shelferry"
cli = app.parent.parent / "Helpers/shelferry"
with tempfile.TemporaryDirectory(prefix="shelferry-test-", dir="/tmp") as temporary:
    directory = Path(temporary)
    env = dict(os.environ, SHELFERRY_DATA_DIR=str(directory / "data"), SHELFERRY_SOCKET_DIR=str(directory / "ipc"))
    def start():
        process = subprocess.Popen([str(app)], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        for _ in range(150):
            if process.poll() is not None:
                raise AssertionError(process.stderr.read().decode())
            if (directory / "ipc/service.sock").exists():
                return process
            time.sleep(0.1)
        process.terminate()
        raise AssertionError("App never became ready")
    def run(*args, success=True):
        result = subprocess.run([str(cli), *args, "--json"], env=env, capture_output=True, text=True, timeout=30)
        assert (result.returncode == 0) == success, (args, result.stdout, result.stderr)
        return json.loads(result.stdout) if result.stdout else None
    process = start()
    try:
        assert run("list")["shelves"] == []
        shelf = run("new", "--name", "Test\tShelf")["shelves"][0]
        original = directory / 'space 日本語\nfile.txt'; original.write_text("original")
        run("add", "--shelf", shelf["id"], str(original))
        run("add", "--shelf", shelf["id"], "--copy", str(original))
        items = run("items", "--shelf", shelf["id"])["items"]
        assert len(items) == 2
        owned = Path(next(x["path"] for x in items if x["isCopy"]))
        assert owned.read_text() == "original" and original.exists()
        run("clear", "--shelf", shelf["id"], success=False)
        assert len(run("items", "--shelf", shelf["id"])["items"]) == 2
        run("rename", "--shelf", shelf["id"], "--name", "Renamed")
        run("toggle"); run("toggle"); run("manager"); run("manager")
        second = subprocess.run([str(app)], env=env, capture_output=True, timeout=10)
        assert second.returncode == 0
        assert len(run("items", "--shelf", shelf["id"])["items"]) == 2
        process.terminate(); process.wait(timeout=10)
        # The next server replaces the stale socket only after acquiring the instance lock.
        (directory / "ipc/service.sock").unlink(missing_ok=True)
        process = start()
        assert run("list")["shelves"][0]["name"] == "Renamed"
        assert len(run("items", "--shelf", shelf["id"])["items"]) == 2
        run("add", "--shelf", shelf["id"], str(directory / "missing"), success=False)
        run("clear", "--shelf", shelf["id"], "--yes")
        for _ in range(50):
            if not owned.exists(): break
            time.sleep(0.02)
        assert original.exists() and not owned.exists()
        run("delete", "--shelf", shelf["id"], "--yes")
        assert run("list")["shelves"] == []
        print("App/CLI integration passed: copy/link, unusual paths, persistence, singleton, toggles, errors and safe deletion.")
    finally:
        if process.poll() is None: process.terminate(); process.wait(timeout=10)
