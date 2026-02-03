import Foundation

final class FileWatcher: @unchecked Sendable {
    private var source: DispatchSourceFileSystemObject?
    private let fileDescriptor: Int32

    init?(directory: String, onChange: @escaping @Sendable () -> Void) {
        fileDescriptor = open(directory, O_EVTONLY)
        guard fileDescriptor >= 0 else { return nil }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .rename],
            queue: .global(qos: .utility)
        )

        source?.setEventHandler {
            DispatchQueue.main.async { onChange() }
        }

        source?.setCancelHandler { [fd = self.fileDescriptor] in
            close(fd)
        }

        source?.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    deinit {
        stop()
    }
}
