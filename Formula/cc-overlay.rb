class CcOverlay < Formula
  desc "Claude Code usage overlay for macOS menu bar"
  homepage "https://github.com/jadru/homebrew-cc-overlay"
  url "https://github.com/jadru/cc-overlay/releases/download/v0.4.0/cc-overlay-v0.4.0-macos.tar.gz"
  sha256 "745eb86c53d3802640ce0fba3c7fb38a423e2fe6d93c86d0a5a65a188a7e4e2c"
  license "MIT"

  depends_on :macos => :sequoia

  def install
    bin.install "cc-overlay"
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
