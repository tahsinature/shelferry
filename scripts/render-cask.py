#!/usr/bin/env python3
"""Generate a pinned Homebrew cask from the exact release archive."""
import hashlib
import pathlib
import re
import sys
version, archive, destination = sys.argv[1:]
if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    raise SystemExit("Expected a semantic version, e.g. 0.1.0")
sha = hashlib.sha256(pathlib.Path(archive).read_bytes()).hexdigest()
pathlib.Path(destination).write_text('''cask "shelferry" do
  version "%s"
  sha256 "%s"

  url "https://github.com/tahsinature/shelferry/releases/download/v#{version}/Shelferry.zip"
  name "Shelferry"
  desc "Native floating file shelves with a CLI and Yazi integration"
  homepage "https://github.com/tahsinature/shelferry"

  depends_on macos: :sonoma

  app "Shelferry.app"
  binary "#{appdir}/Shelferry.app/Contents/Helpers/shelferry"

  uninstall quit: "us.tahsin.shelferry"

  caveats <<~EOS
    Shelferry is not Apple-notarized.
    If macOS blocks it, review and allow it in System Settings > Privacy & Security.
    Yazi plugin: ya pkg add tahsinature/shelferry:shelferry
  EOS
end
''' % (version, sha))
