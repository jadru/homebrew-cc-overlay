class CcOverlay < Formula
  desc "Claude Code & Codex CLI usage overlay for macOS menu bar"
  homepage "https://github.com/jadru/homebrew-cc-overlay"
  url "https://github.com/jadru/cc-overlay/releases/download/v0.9.0/cc-overlay-v0.9.0-macos.tar.gz"
  sha256 "9240030f3d5b1b92a01eeac73f711166f433c1bc686d88b0a6da4aeb363ea356"
  license "MIT"

  depends_on :macos => :sequoia

  def install
    # .app bundle structure required by macOS GUI frameworks
    # (UNUserNotificationCenter, SwiftData, etc.)
    app_dir = prefix/"CC-Overlay.app/Contents"
    (app_dir/"MacOS").mkpath

    (app_dir/"MacOS").install "cc-overlay"
    app_dir.install "Info.plist"

    entitlements = buildpath/"cc-overlay.entitlements"
    entitlements.write <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>com.apple.security.network.client</key>
          <true/>
      </dict>
      </plist>
    XML
    system "codesign", "--force", "--sign", "-",
           "--entitlements", entitlements,
           "--timestamp=none", app_dir/"MacOS/cc-overlay"

    bin.install_symlink app_dir/"MacOS/cc-overlay"
  end

  service do
    run [opt_prefix/"CC-Overlay.app/Contents/MacOS/cc-overlay"]
    keep_alive crashed: true
    log_path var/"log/cc-overlay.log"
    process_type :interactive
  end

  test do
    assert_predicate bin/"cc-overlay", :executable?
  end
end
