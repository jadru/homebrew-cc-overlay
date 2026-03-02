import Foundation

enum CLIBinaryFinder {
    static func findInNvmVersions(_ binary: String, home: String) -> String? {
        let nvmDir = "\(home)/.nvm/versions/node"
        guard let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmDir) else {
            return nil
        }
        for version in versions.sorted(by: semanticVersionDescending) {
            let path = "\(nvmDir)/\(version)/bin/\(binary)"
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    static func semanticVersionDescending(_ a: String, _ b: String) -> Bool {
        let partsA = a.drop(while: { !$0.isNumber }).split(separator: ".").compactMap { Int($0) }
        let partsB = b.drop(while: { !$0.isNumber }).split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(partsA.count, partsB.count) {
            let va = i < partsA.count ? partsA[i] : 0
            let vb = i < partsB.count ? partsB[i] : 0
            if va != vb { return va > vb }
        }
        return false
    }

    static func resolveFromPATH(_ command: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return result?.isEmpty == false ? result : nil
        } catch {
            return nil
        }
    }
}
