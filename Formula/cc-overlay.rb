class CcOverlay < Formula
  desc "Claude Code & Codex CLI usage overlay for macOS menu bar"
  homepage "https://github.com/jadru/homebrew-cc-overlay"
  url "https://github.com/jadru/cc-overlay/releases/download/v0.5.0/cc-overlay-v0.5.0-macos.tar.gz"
  sha256 "240161872bd624a1a2e3284f35c6d8bd2a09a3eb38d15bd0639da09e06339d56"
  license "MIT"

  depends_on :macos => :sequoia

  def install
    bin.install "cc-overlay"
    # Entitlements for outbound network access (prevents repeated macOS permission dialogs)
    entitlements = buildpath/"cc-overlay.entitlements"
    entitlements.write <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>com.apple.security.network.client</key>
          <true/>
      </dict>
      </plist>
    XML
    system "codesign", "--force", "--sign", "-",
           "--entitlements", entitlements,
           "--timestamp=none", bin/"cc-overlay"
  end

  service do
    run [opt_bin/"cc-overlay"]
    keep_alive true
    log_path var/"log/cc-overlay.log"
  end

  test do
    assert_predicate bin/"cc-overlay", :executable?
  end
end
