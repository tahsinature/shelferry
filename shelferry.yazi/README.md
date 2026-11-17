# Shelferry for Yazi

Send selected or hovered files to native macOS shelves and retrieve shelf items for copying or moving. This plugin uses the `shelferry` CLI, without deep links or direct access to app storage.

## Install

Install [Shelferry](https://github.com/tahsinature/shelferry) first, then:

```sh
ya pkg add tahsinature/shelferry:shelferry
```

Add these entries to your Yazi `keymap.toml`:

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

## Actions

- `add`: choose a shelf or create one, then choose independent copies or links to originals.
- `get`: select shelf items, choose copy or cut, and press `p` in Yazi’s destination folder.
- `toggle`: show or hide all shelves.

`fzf` is optional. Without it, shelf selection uses a paginated key menu, and retrieving items offers an explicit select-all choice. With `fzf`, use Tab for multiple selections and Ctrl+A to select all.

The CLI must be in PATH. Set `SHELFERRY_BIN` to its full path if needed. The plugin starts the app automatically through the CLI. Paths containing spaces, Unicode, tabs and newlines are passed as individual arguments and returned as JSON.

Existing Tooki Yazi bindings are left untouched. Change your bindings when you are ready to switch.

Requires macOS 14+, Shelferry, and a Yazi version supporting the current plugin API. Licensed under [MIT](LICENSE).
