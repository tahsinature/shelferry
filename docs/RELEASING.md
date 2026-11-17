# Releases

Push changes to `master`; CI builds and tests them. To publish, open GitHub Actions → Release → Run workflow on `master` and enter a version such as `0.1.1`. Existing versions cannot be overwritten.

The workflow runs tests, builds the universal app/CLI, runs isolated integration checks, verifies both architectures and the bundle signature, creates a ZIP and SHA-256, and publishes a GitHub release. Its generated `shelferry.rb` pins that exact archive.

The `Update Shelferry` workflow in `tahsinature/homebrew-tap` checks every six hours. Dispatch it manually after a release for immediate availability. It verifies the downloaded ZIP against the generated cask before committing. No cross-repository PAT is required.

Install or update:

```sh
brew install --cask tahsinature/tap/shelferry
brew upgrade --cask shelferry
```

Releases use a stable self-signed certificate when configured, otherwise ad-hoc signing. They are not notarized. The cask does not remove quarantine. A future notarized release needs Developer ID signing and Apple notarization credentials; configure those explicitly rather than copying private credentials from another app.

Keep protocol version 1 backward compatible while the plugin and app can be upgraded independently. Breaking changes require a protocol version increase and a clear CLI error for incompatible clients. The Yazi package manager pins the plugin revision separately from the installed app.

## In-app updates

Shelferry uses Sparkle 2.10.1, following Tooki’s native Swift implementation.
Production builds expose Check for Updates and Settings → Updates. Automatic
checking defaults to on, matching Tooki, and can be switched off. Sparkle owns
the preference, download UI and installation. Updates are presented for approval.
Development builds and isolated integration runs do not start the updater.
Update restarts wait for CLI requests, file copies and open conversion sessions.

The release workflow signs the ZIP and publishes `appcast.xml` alongside it.
The feed is `https://github.com/tahsinature/shelferry/releases/latest/download/appcast.xml`.
Archives use version-specific HTTPS URLs. `CFBundleVersion` must keep increasing;
the workflow uses its run number. The first Sparkle-enabled version requires a
normal installation or Homebrew upgrade before it can receive future updates.

The public Ed25519 key is in `Resources/Info.plist`. The private key lives in the
login Keychain under account `us.tahsin.shelferry`, and in the repository’s encrypted
`SPARKLE_PRIVATE_KEY` Actions secret. Never regenerate it per release or commit it.
Local `scripts/generate-appcast.sh` uses the Keychain; CI supplies the key through stdin.
To restore the key on another Mac, use Sparkle’s `generate_keys --account
us.tahsin.shelferry -f <private-key-file>`. To restore CI, pass that file on stdin
to `gh secret set SPARKLE_PRIVATE_KEY --repo tahsinature/shelferry`.

Stable application signing is configured with `SIGNING_CERT_P12` (base64 PKCS#12) and
`SIGNING_CERT_PASSWORD` Actions secrets, with identity `Shelferry Release Signing`.
Without these, the workflow falls back to ad-hoc signing and warns. Preserve this
certificate and its private key across releases. Sparkle’s Ed25519 key and the
application signing certificate serve different purposes; neither substitutes
for Apple notarization. No quarantine removal is performed by the cask.
