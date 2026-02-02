import Foundation

/// Represents a Claude Code session that is currently running.
struct ActiveSession: Identifiable, Sendable, Equatable {
    let id: String
    let pid: Int32
    let processStartTime: Date
    let projectPath: String?
    let projectName: String?
    let gitBranch: String?
    let messageCount: Int?
    let lastModified: Date?
    let model: String?
    let permissionMode: String?
    let isSidechain: Bool
    let parentAppBundleId: String?
    let parentAppName: String?

    var duration: TimeInterval {
        Date().timeIntervalSince(processStartTime)
    }

    var displayName: String {
        projectName ?? "Unknown Project"
    }
}
