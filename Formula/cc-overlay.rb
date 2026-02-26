class CcOverlay < Formula
  desc "Claude Code & Codex CLI usage overlay for macOS menu bar"
  homepage "https://github.com/jadru/homebrew-cc-overlay"
  url "https://github.com/jadru/cc-overlay/releases/download/v0.6.0/cc-overlay-v0.6.0-macos.tar.gz"
  sha256 "e385686990ea2f0baff9901be466c92e06563665fb8c819c8320c5b3174b3c33"
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
    keep_alive crashed: true
    log_path var/"log/cc-overlay.log"
  end

  test do
    assert_predicate bin/"cc-overlay", :executable?
  end
end
