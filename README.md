<p align="center">
  <img src="Resources/Logo.svg" alt="Shelferry Paper Stack logo" width="96" height="96">
</p>

# Shelferry

Native floating file shelves for macOS, with a CLI for launchers and a Yazi plugin.

Carry files between apps: drop them onto a shelf, keep links to originals or independent copies, then drag them out when you need them. Shelferry includes Quick Look, multiple floating shelves, and image conversion.

## Install

Requires macOS 14 or later. The app and CLI install together:

```sh
brew tap tahsinature/tap
brew trust tahsinature/tap
brew install --cask shelferry
```

You can also download `Shelferry.zip` from [Releases](https://github.com/tahsinature/shelferry/releases). Initial releases are ad-hoc signed, not Apple-notarized. macOS may require approval in **System Settings → Privacy & Security**. Shelferry does not remove quarantine protections automatically.

## CLI

```sh
shelferry new --name Work
shelferry add --shelf Work --copy -- ~/Downloads/report.pdf
shelferry list --json
shelferry toggle
shelferry settings
```

The app starts automatically. Use JSON and stable shelf IDs when integrating with Tooki, Raycast, Asyar, Alfred, Yazi, or other tools. Pass filenames as separate arguments after `--`. The CLI handles validation and communicates with the app; integrations never need to manage shelf storage.

## Yazi

```sh
ya pkg add tahsinature/shelferry:shelferry
```

See the [plugin guide](shelferry.yazi/README.md) for key bindings. The app, CLI and plugin live in this repository and are maintained together.

## Preferences

General, Hotkeys and About are available from the menu bar’s Settings window. Global hotkeys start unassigned.

Settings are stored in `~/.config/shelferry/config.json`. UI changes save automatically, and external edits reload within a second. Symlinked config files are supported. Invalid edits preserve the last valid configuration. Shelf contents and copies remain in `~/Library/Application Support/Shelferry`, separately from Tooki.

## Documentation

- [Usage and configuration](docs/USAGE.md)
- [CLI contract and launcher integrations](docs/INTEGRATIONS.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Build and release workflow](docs/RELEASING.md)
- [Raycast example](examples/raycast/toggle-shelves.sh) and [Alfred example](examples/alfred/list-shelves.py)

## Build

Use Swift 6.4 / Xcode 27.2 or later. Full Xcode is required for the test suite; app builds can use compatible Command Line Tools.

```sh
make test
make app
open build/Shelferry.app
```

`ARCHS="arm64 x86_64" make app` builds a universal archive. CI runs unit and app/CLI integration tests. The Release workflow publishes a versioned archive and checksum; the Homebrew tap updates from verified release assets.

## License

[MIT](LICENSE) © 2026 Tahsin. Third-party dependencies retain their own licenses, included in [ThirdPartyNotices.txt](Resources/ThirdPartyNotices.txt).
