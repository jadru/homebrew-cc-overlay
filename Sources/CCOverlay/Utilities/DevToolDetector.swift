import AppKit

enum DevToolDetector {
    static let whitelistedBundleIds: Set<String> = [
        // Terminals
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "net.kovidgoyal.kitty",
        "com.mitchellh.ghostty",
        "io.alacritty",
        // IDEs & Editors
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.todesktop.230313mzl4w4u92",  // Cursor
        "com.apple.dt.Xcode",
        "com.sublimetext.4",
        "com.sublimetext.3",
        // Claude
        "com.anthropic.claudefordesktop",
        // Conductor
        "com.conductor.app",
    ]

    static let whitelistedPrefixes: [String] = [
        "com.jetbrains.",
    ]

    static func isWhitelisted(_ bundleId: String) -> Bool {
        if whitelistedBundleIds.contains(bundleId) { return true }
        for prefix in whitelistedPrefixes where bundleId.hasPrefix(prefix) { return true }
        return false
    }

    static func isCurrentAppDevTool() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleId = app.bundleIdentifier else { return false }
        return isWhitelisted(bundleId)
    }
}
