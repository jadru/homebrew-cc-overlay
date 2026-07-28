class CcOverlay < Formula
  desc "Claude Code & Codex CLI usage overlay for macOS menu bar"
  homepage "https://github.com/jadru/homebrew-cc-overlay"
  url "https://github.com/jadru/homebrew-cc-overlay/releases/download/v0.11.0/CC-Overlay-v0.11.0-macos.zip"
  sha256 "a83d2616f3a4b1be246c22b59928ffca388cb067b7358d92e1daef700b13f972"
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
