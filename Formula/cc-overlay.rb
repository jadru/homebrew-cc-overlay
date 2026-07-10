class CcOverlay < Formula
  desc "Claude Code & Codex CLI usage overlay for macOS menu bar"
  homepage "https://github.com/jadru/homebrew-cc-overlay"
  url "https://github.com/jadru/homebrew-cc-overlay/releases/download/v0.10.0/CC-Overlay-v0.10.0-macos.zip"
  sha256 "26c97c6f791de741f7d7f3956c902846e2ea2f043a77c91551386f1699e58c07"
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

    executable = prefix/"CC-Overlay.app/Contents/MacOS/cc-overlay"
    bin.write_exec_script executable
  end

  test do
    assert_predicate bin/"cc-overlay", :executable?
    assert_predicate prefix/"CC-Overlay.app/Contents/Info.plist", :exist?
  end
end
