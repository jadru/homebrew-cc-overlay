import Foundation

final class FileWatcher: @unchecked Sendable {
    private var sources: [DispatchSourceFileSystemObject] = []

    init?(directory: String, onChange: @escaping @Sendable () -> Void) {
        let paths = Self.observedPaths(rootDirectory: directory)
        guard !paths.isEmpty else { return nil }

        for path in paths {
            let fileDescriptor = open(path, O_EVTONLY)
            guard fileDescriptor >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: [.write, .extend, .rename, .delete],
                queue: .global(qos: .utility)
            )

            source.setEventHandler {
                DispatchQueue.main.async(execute: onChange)
            }
            source.setCancelHandler {
                close(fileDescriptor)
            }
            source.resume()
            sources.append(source)
        }

        guard !sources.isEmpty else { return nil }
    }

    func stop() {
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
    }

    deinit {
        stop()
    }

    private static func observedPaths(rootDirectory: String) -> [String] {
        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: rootDirectory)
        guard let projectDirectories = try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return fileManager.fileExists(atPath: rootDirectory) ? [rootDirectory] : []
        }

        var paths = [rootDirectory]
        for projectDirectory in projectDirectories {
            guard (try? projectDirectory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                continue
            }
            paths.append(projectDirectory.path)

            if let files = try? fileManager.contentsOfDirectory(at: projectDirectory, includingPropertiesForKeys: nil) {
                paths.append(contentsOf: files.filter { $0.pathExtension == "jsonl" }.map(\.path))
            }
        }
        return paths
    }
}
