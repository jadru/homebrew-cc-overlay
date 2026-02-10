class CcOverlay < Formula
  desc "Claude Code usage overlay for macOS menu bar"
  homepage "https://github.com/jadru/homebrew-cc-overlay"
  url "https://github.com/jadru/cc-overlay/releases/download/v0.1.0/cc-overlay-v0.1.0-macos.tar.gz"
  sha256 "e1a38175c5a4b46d14064c3090ff1c5d69b907c97edc1b0ec7963ba2a171150b"
  license "MIT"

  depends_on :macos => :tahoe

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
