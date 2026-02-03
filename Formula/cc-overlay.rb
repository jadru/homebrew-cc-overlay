class CcOverlay < Formula
  desc "Claude Code usage overlay for macOS menu bar"
  homepage "https://github.com/jadru/cc-overlay"
  url "https://github.com/jadru/cc-overlay/releases/download/v0.1.0/cc-overlay-v0.1.0-macos.tar.gz"
  sha256 "PLACEHOLDER"
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
