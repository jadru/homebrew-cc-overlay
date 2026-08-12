class CcOverlay < Formula
  desc "Claude Code & Codex CLI usage overlay for macOS menu bar"
  homepage "https://github.com/jadru/homebrew-cc-overlay"
  url "https://github.com/jadru/homebrew-cc-overlay/releases/download/v0.14.1/CC-Overlay-v0.14.1-macos.zip"
  sha256 "e036ce4b41576ee1fee5f89b46a55185af07c9aea309e458e6123adf61bf392b"
  license "MIT"

  depends_on :macos => :sequoia

  def install
    app_bundle = buildpath
    unless app_bundle.directory? && app_bundle.basename.to_s == "CC-Overlay.app"
      odie "Release archive must contain CC-Overlay.app"
    end

    destination = prefix/"CC-Overlay.app"
    destination.mkpath
    system "ditto", app_bundle/"Contents", destination/"Contents"

    executable = prefix/"CC-Overlay.app/Contents/MacOS/cc-overlay"
    wrapper = bin/"cc-overlay"
    wrapper.write <<~SH
      #!/bin/bash
      exec "#{executable}" "$@"
    SH
    wrapper.chmod 0755
  end

  test do
    assert_predicate bin/"cc-overlay", :executable?
    assert_predicate prefix/"CC-Overlay.app/Contents/Info.plist", :exist?
    assert_predicate prefix/"CC-Overlay.app/Contents/Resources/CC-Overlay_CCOverlay.bundle/ProviderIcons/claude-code.svg", :exist?
    assert_predicate prefix/"CC-Overlay.app/Contents/Resources/CC-Overlay_CCOverlay.bundle/ProviderIcons/codex.svg", :exist?
  end
end
