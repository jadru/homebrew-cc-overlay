class CcOverlay < Formula
  desc "Claude Code usage overlay for macOS menu bar"
  homepage "https://github.com/jadru/homebrew-cc-overlay"
  url "https://github.com/jadru/cc-overlay/releases/download/v0.2.0/cc-overlay-v0.2.0-macos.tar.gz"
  sha256 "483d66a2647ffef412994e2af1afb243d3cd806aa4d391ed8ed0e6be08f62485"
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
