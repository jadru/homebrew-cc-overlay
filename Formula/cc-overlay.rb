class CcOverlay < Formula
  desc "Claude Code & Codex CLI usage overlay for macOS menu bar"
  homepage "https://github.com/jadru/homebrew-cc-overlay"
  url "https://github.com/jadru/homebrew-cc-overlay/releases/download/v0.9.1/cc-overlay-v0.9.1-macos.tar.gz"
  sha256 "e86ea3e96d426576b022cbfcd12a0c26de9ae73196408957ba0a1df807317e40"
  license "MIT"

  depends_on :macos => :sequoia

  def install
    if (buildpath/"CC-Overlay.app").directory?
      prefix.install "CC-Overlay.app"
    else
      app_dir = prefix/"CC-Overlay.app/Contents"
      (app_dir/"MacOS").mkpath
      (app_dir/"MacOS").install "cc-overlay"
      app_dir.install "Info.plist"
      system "codesign", "--force", "--sign", "-", "--timestamp=none", app_dir/"MacOS/cc-overlay"
    end

    bin.install_symlink prefix/"CC-Overlay.app/Contents/MacOS/cc-overlay"
  end

  test do
    assert_predicate bin/"cc-overlay", :executable?
    assert_predicate prefix/"CC-Overlay.app/Contents/Info.plist", :exist?
  end
end
