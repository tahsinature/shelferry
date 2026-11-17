# Shelferry

A native floating shelf for carrying files between apps. Extracted from the Swift implementation of Tooki, with a standalone app, CLI, and Yazi plugin.

## Install

```sh
brew tap tahsinature/tap
brew trust tahsinature/tap
brew install --cask shelferry
```

The app and `shelferry` command install together. Requires macOS 14 or later. Initial releases are ad-hoc signed, not Apple-notarized. If macOS blocks a downloaded app, review it and allow it in System Settings → Privacy & Security. This project does not automatically remove quarantine protections.

## Use

Open Shelferry from Applications. Drop files onto a shelf, choosing links to originals or independent copies. Hold Shift during a file drag to show a shelf. Use the menu bar to create shelves, toggle visibility, open Shelf Manager, or change drag preferences. Quick Look, multi-file dragging, renaming, and image conversion come from Tooki's native Shelf.

```sh
shelferry new --name Work
shelferry add --shelf Work --copy -- ~/Downloads/report.pdf
shelferry list --json
shelferry items --shelf Work --json
shelferry toggle
shelferry manager
shelferry clear --shelf Work --yes
```

`clear` empties a shelf; `delete` removes the shelf. Both remove owned copies permanently. Original files remain untouched. Use IDs when names are duplicated. Use JSON for automation, or `items --null` for NUL-delimited paths. Human-readable output is not a parsing contract. A timed-out change may have completed; inspect the shelf before retrying.

## Yazi

```sh
ya pkg add tahsinature/shelferry:shelferry
```

Add bindings to your Yazi `keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on = ["g", "s"]
run = "plugin shelferry -- add"
desc = "Add to Shelferry"

[[mgr.prepend_keymap]]
on = ["g", "S"]
run = "plugin shelferry -- get"
desc = "Get from Shelferry"
```

The plugin also accepts `toggle` and `manager`. `fzf` is optional; without it, shelf selection uses a paginated key menu. Set `SHELFERRY_BIN` if the CLI is outside PATH. The plugin passes paths as individual arguments and uses JSON, so spaces, Unicode, tabs and newlines stay intact.

Existing Tooki plugin installations and data are not migrated automatically. They can coexist. Install this plugin and switch your bindings when ready.

## Build

Requires Swift 6.4 / Xcode 27.2 (Command Line Tools can build the app; full Xcode is recommended for tests).

```sh
make test
make app
open build/Shelferry.app
```

`ARCHS="arm64 x86_64" make app` creates a universal app. `CONFIGURATION=debug make app` creates a development build. Data lives in `~/Library/Application Support/Shelferry`; Tooki storage is never read or modified. Test overrides: `SHELFERRY_DATA_DIR`, `SHELFERRY_SOCKET_DIR`, and CLI `SHELFERRY_APP`.

## Preferences and hotkeys

Open Settings from the Shelferry menu bar. General contains drag preferences, Hotkeys records global shortcuts, and About links to help and source code. Hotkeys start unassigned and require no Accessibility permission.

Settings save to `~/.config/shelferry/config.json`. Shelferry reloads external edits within a second, including atomic editor saves and edits to symlink targets. Invalid files keep the last valid settings active and show an error in Settings. UI writes preserve symlinks. Shelf data and copies remain in Application Support. `SHELFERRY_CONFIG_DIR` overrides the configuration directory.

```json
{
  "shiftDragOpens": true,
  "removeAfterDragOut": false,
  "shortcuts": {
    "toggle": "ctrl+opt+s",
    "newShelf": "ctrl+opt+n",
    "manager": "ctrl+opt+m"
  }
}
```

These are example hotkeys, not defaults. Remove an entry to unassign it. Conflicts with other apps are reported in Settings. See [the integration guide](INTEGRATIONS.md) for launcher APIs and examples.
