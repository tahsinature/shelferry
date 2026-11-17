# Releases

Push changes to `master`; CI builds and tests them. To publish, open GitHub Actions → Release → Run workflow on `master` and enter a version such as `0.1.1`. Existing versions cannot be overwritten.

The workflow runs tests, builds the universal app/CLI, runs isolated integration checks, verifies both architectures and the bundle signature, creates a ZIP and SHA-256, and publishes a GitHub release. Its generated `shelferry.rb` pins that exact archive.

The `Update Shelferry` workflow in `tahsinature/homebrew-tap` checks every six hours. Dispatch it manually after a release for immediate availability. It verifies the downloaded ZIP against the generated cask before committing. No cross-repository PAT is required.

Install or update:

```sh
brew install --cask tahsinature/tap/shelferry
brew upgrade --cask shelferry
```

Releases are ad-hoc signed, not notarized. The cask does not remove quarantine. A future notarized release needs Developer ID signing and Apple notarization credentials; configure those explicitly rather than copying private credentials from another app.

Keep protocol version 1 backward compatible while the plugin and app can be upgraded independently. Breaking changes require a protocol version increase and a clear CLI error for incompatible clients. The Yazi package manager pins the plugin revision separately from the installed app.
