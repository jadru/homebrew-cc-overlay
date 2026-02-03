import Foundation

struct SessionIndexFile: Codable, Sendable {
    let version: Int
    let entries: [SessionIndexEntry]
    let originalPath: String?
}

struct SessionIndexEntry: Codable, Sendable {
    let sessionId: String
    let fullPath: String
    let fileMtime: Int64?
    let firstPrompt: String?
    let messageCount: Int?
    let created: String?
    let modified: String?
    let gitBranch: String?
    let projectPath: String?
    let isSidechain: Bool?
}
