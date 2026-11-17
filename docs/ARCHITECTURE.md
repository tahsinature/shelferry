# Architecture

Shelferry is extracted from Tooki's original Swift Shelf, retaining its AppKit panels, SwiftUI content, drag/drop, Quick Look, and image conversion. Shelferry is independently distributed under the MIT License; third-party dependency licenses remain in ThirdPartyNotices.txt.

- `ShelferryApp`: single owner of shelf state and disk writes. Native `ShelfPanel` instances host SwiftUI views. `ShelfLibrary` owns shelves; `ShelfWindows` owns panels.
- `ShelfFeature`: existing TCA reducers for selection, confirmation and conversion.
- `ShelferryCore`: portable helpers and native image conversion services used by those reducers.
- `ShelferryDesignSystem`: colors and interaction styles used by floating shelves and settings.
- `ShelferryProtocol`: versioned JSON requests/replies, argument parsing, same-user Unix socket transport.
- `ShelferryCLI`: validates arguments, launches the app when necessary, sends one request, prints results and exits with a meaningful status.
- `shelferry.yazi`: selected/hovered file collection and picker UI. All shelf operations go through the CLI.

## Process boundary

The socket is `/tmp/shelferry-<uid>/service.sock`, inside an owner-only directory. Both ends verify peer UID. The app holds an exclusive lock for its lifetime; a second process exits before loading storage. The serial accept loop forwards commands to the main actor. Requests have a 1 MiB bound; read/write timeouts prevent indefinite client waits. The CLI does not modify shelf files directly.

No deep-link handler, external server, network port, or separate background daemon is required. The app remains alive in the menu bar.

## Distribution

CI tests reducers, CLI parsing, and an isolated app/CLI integration flow. The manually dispatched Release workflow tests before building a universal archive, verifies signatures/architectures, computes its SHA-256, and publishes a release plus generated cask. The Homebrew tap checks for releases on a schedule and can be dispatched immediately. That workflow uses its own repository token, avoiding an extra cross-repository secret.

Signing is currently ad hoc. Developer ID signing and Apple notarization require an appropriate Apple Developer identity and credentials; no existing Tooki signing keys are exported or reused.
