import Foundation

/// Incrementally reads recent Claude Code JSONL transcripts. A full file is parsed
/// once; subsequent scans read only bytes appended after the prior offset.
struct ClaudeSessionScanner: Sendable {
    struct FileState: Sendable {
        let offset: UInt64
        let modificationDate: Date
        let entries: [ParsedUsageEntry]
        let trailingLine: Data
    }

    struct ScanResult: Sendable {
        let entries: [ParsedUsageEntry]
        let fileStates: [String: FileState]
    }

    static func scan(
        projectsPath: String,
        previousStates: [String: FileState],
        now: Date = Date()
    ) throws -> ScanResult {
        let fileManager = FileManager.default
        let projectsURL = URL(fileURLWithPath: projectsPath)
        guard fileManager.fileExists(atPath: projectsURL.path) else {
            return ScanResult(entries: [], fileStates: [:])
        }

        let cutoff = now.addingTimeInterval(-AppConstants.claudeTranscriptLookback)
        let projectDirectories = try fileManager.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        var nextStates: [String: FileState] = [:]

        for projectDirectory in projectDirectories {
            let values = try projectDirectory.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { continue }

            let files: [URL]
            do {
                files = try fileManager.contentsOfDirectory(
                    at: projectDirectory,
                    includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
                ).filter { $0.pathExtension == "jsonl" }
            } catch {
                continue
            }

            for file in files {
                let resourceValues = try file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                guard let modificationDate = resourceValues.contentModificationDate,
                      modificationDate >= cutoff,
                      let fileSize = resourceValues.fileSize
                else {
                    continue
                }

                let path = file.path
                let size = UInt64(fileSize)
                let projectName = projectDirectory.lastPathComponent
                let sessionId = file.deletingPathExtension().lastPathComponent

                if let previous = previousStates[path],
                   previous.offset == size,
                   previous.modificationDate == modificationDate
                {
                    nextStates[path] = previous
                    continue
                }

                let mustRestart = previousStates[path].map {
                    size < $0.offset || (size == $0.offset && modificationDate != $0.modificationDate)
                } ?? true

                let state: FileState
                if mustRestart {
                    let data = try Data(contentsOf: file)
                    let result = JSONLParser.parseCompleteLines(
                        in: data,
                        sessionId: sessionId,
                        projectName: projectName
                    )
                    state = FileState(
                        offset: UInt64(data.count),
                        modificationDate: modificationDate,
                        entries: result.entries,
                        trailingLine: result.trailingLine
                    )
                } else if let previous = previousStates[path] {
                    let appendedData = try readAppendedData(from: file, offset: previous.offset)
                    let result = JSONLParser.parseCompleteLines(
                        in: previous.trailingLine + appendedData,
                        sessionId: sessionId,
                        projectName: projectName
                    )
                    state = FileState(
                        offset: size,
                        modificationDate: modificationDate,
                        entries: previous.entries + result.entries,
                        trailingLine: result.trailingLine
                    )
                } else {
                    continue
                }

                nextStates[path] = state
            }
        }

        return ScanResult(
            entries: nextStates.values.flatMap(\.entries),
            fileStates: nextStates
        )
    }

    static func hasRecentSession(
        projectsPath: String,
        now: Date = Date()
    ) -> Bool {
        let fileManager = FileManager.default
        let projectsURL = URL(fileURLWithPath: projectsPath)
        guard let projectDirectories = try? fileManager.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return false
        }

        let cutoff = now.addingTimeInterval(-AppConstants.claudeTranscriptLookback)
        for projectDirectory in projectDirectories {
            guard (try? projectDirectory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                  let files = try? fileManager.contentsOfDirectory(
                      at: projectDirectory,
                      includingPropertiesForKeys: [.contentModificationDateKey]
                  )
            else {
                continue
            }

            if files.contains(where: { file in
                file.pathExtension == "jsonl" &&
                    ((try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) >= cutoff
            }) {
                return true
            }
        }

        return false
    }

    private static func readAppendedData(from file: URL, offset: UInt64) throws -> Data {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        try handle.seek(toOffset: offset)
        return try handle.readToEnd() ?? Data()
    }
}
