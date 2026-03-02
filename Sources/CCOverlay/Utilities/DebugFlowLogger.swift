import Foundation

enum UIFlowStage: String, Sendable {
    case detection
    case display
    case alert
}

struct UIFlowEvent: Sendable, Equatable {
    let stage: UIFlowStage
    let provider: CLIProvider?
    let message: String
    let details: [String: String]
    let timestamp: Date
}

protocol DebugFlowEventSink: AnyObject {
    func record(_ event: UIFlowEvent)
}

final class DebugFlowLogger {
    nonisolated(unsafe) static let shared = DebugFlowLogger()

    var isEnabled = false

    private let maxEventCount = 250
    private var sink: DebugFlowEventSink?
    private(set) var events: [UIFlowEvent] = []

    func configure(enabled: Bool, sink: DebugFlowEventSink? = nil) {
        isEnabled = enabled
        self.sink = sink
        if !enabled {
            events.removeAll()
        }
    }

    func setSink(_ sink: DebugFlowEventSink?) {
        self.sink = sink
    }

    func clear() {
        events.removeAll()
    }

    func log(
        stage: UIFlowStage,
        provider: CLIProvider? = nil,
        message: String,
        details: [String: String] = [:]
    ) {
        guard isEnabled else { return }

        let event = UIFlowEvent(
            stage: stage,
            provider: provider,
            message: message,
            details: details,
            timestamp: Date()
        )

        events.append(event)
        if events.count > maxEventCount {
            events.removeFirst(events.count - maxEventCount)
        }

        sink?.record(event)

        let providerText = provider?.rawValue ?? "general"
        let detailsText = details
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: ", ")

        if detailsText.isEmpty {
            AppLogger.ui.debug("[FLOW] [\(stage.rawValue.uppercased())] [\(providerText)] \(message)")
        } else {
            AppLogger.ui.debug("[FLOW] [\(stage.rawValue.uppercased())] [\(providerText)] \(message) — \(detailsText)")
        }
    }
}
