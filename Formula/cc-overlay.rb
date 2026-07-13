class CcOverlay < Formula
  desc "Claude Code & Codex CLI usage overlay for macOS menu bar"
  homepage "https://github.com/jadru/homebrew-cc-overlay"
  url "https://github.com/jadru/homebrew-cc-overlay/releases/download/v0.10.5/CC-Overlay-v0.10.5-macos.zip"
  sha256 "90711525472567e6c696585e81744443be40544fc3c46d635f73bdc2af647663"
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
