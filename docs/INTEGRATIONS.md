# Integrating Shelferry

Tooki, Raycast, Asyar, Alfred and Yazi should invoke the same `shelferry` CLI. Integrations select files and present results; Shelferry owns storage, native windows and file operations. Do not read or write its data files or depend on its private socket protocol.

## Contract

- Invoke the executable with an argument array, without a shell. Put file paths after `--`.
- Add `--json` before `--`. Standard output contains one JSON object, including for validation and connection failures. Standard error contains human diagnostics. Exit status is 0 for success and 1 for failure.
- JSON has `version: 1`, `shelves: []`, `items: []`, and an optional `error` string. Ignore unknown fields. `version` describes the output contract, not the app release.
- Shelf objects have `id`, `name`, and `count`. Item objects have `id`, `path`, and `isCopy`. IDs survive restart. Names may collide, so store IDs.
- `list` and `items` do not show a window. The app starts in the background if needed. `add` shows its destination; `new` shows the new shelf. `show`, `hide`, `toggle`, and `manager` control windows.
- `add --copy` completes its copies before reporting success. Default `add` links to originals. Pass `--shelf new` to create a shelf, or an existing ID to target one.
- `clear` and `delete` require an explicit shelf and `--yes`. Get confirmation in your integration before invoking them. Owned copies are permanently deleted; originals remain untouched.
- Wait asynchronously in GUI integrations. Large copies can take time. A timeout is not a rollback: inspect state before retrying a mutation. There is no idempotency-key or event-stream API in version 1.
- For paths without JSON use `items --shelf ID --null`. Do not parse human-readable tabular output.

## Executable discovery

Homebrew links `shelferry` into its bin directory. GUI launchers may not inherit terminal PATH. Allow users to configure its location, then try PATH, `/opt/homebrew/bin/shelferry` and `/usr/local/bin/shelferry`. A direct app installation also contains `/Applications/Shelferry.app/Contents/Helpers/shelferry`.

## Common calls

```text
["list", "--json"]
["items", "--shelf", shelfID, "--json"]
["add", "--shelf", shelfID, "--copy", "--json", "--", ...filePaths]
["toggle", "--shelf", shelfID, "--json"]
["manager", "--json"]
```

Use `std::process::Command` / an asynchronous process wrapper in Rust, `Process` in Swift, or Node's `execFile` in a TypeScript launcher. Pass each argument separately and inspect both the exit code and JSON error.

## Included adapters

- Yazi: `shelferry.yazi/`, install with `ya pkg add tahsinature/shelferry:shelferry`.
- Raycast: add `examples/raycast/` as a Script Commands directory. The supplied command toggles shelves.
- Alfred: use `examples/alfred/list-shelves.py` as a Script Filter, then connect its argument to a Run Script calling `shelferry show --shelf "$1"`. Configure the executable path if needed.
- Tooki and Asyar: use the common calls above from their existing command providers. No Shelferry-specific storage or native bridge is needed.

The Raycast and Alfred files are small integration examples; the app/CLI integration is tested independently of those launchers.
