import Foundation

/// Parses local Gemini CLI telemetry and session data to estimate usage.
/// Gemini CLI has no remote usage API, so we rely on local files.
actor GeminiTelemetryParser {
    struct UsageEstimate: Sendable {
        let requestCount: Int
        let estimatedTokensInput: Int
        let estimatedTokensOutput: Int
        let requestTimestamps: [Date]
        let sessionCount: Int
        let model: String?

        /// Requests in the last 60 seconds.
        var rpmEstimate: Double {
            let cutoff = Date().addingTimeInterval(-60)
            return Double(requestTimestamps.filter { $0 > cutoff }.count)
        }

        /// Requests in the last 24 hours (midnight Pacific reset approximated).
        var rpdEstimate: Double {
            let cutoff = Date().addingTimeInterval(-86400)
            return Double(requestTimestamps.filter { $0 > cutoff }.count)
        }

        static let empty = UsageEstimate(
            requestCount: 0,
            estimatedTokensInput: 0,
            estimatedTokensOutput: 0,
            requestTimestamps: [],
            sessionCount: 0,
            model: nil
        )
    }

    private let configPath: String

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let isoFallbackFormatter = ISO8601DateFormatter()

    init(configPath: String = AppConstants.geminiConfigPath) {
        self.configPath = configPath
    }

    // MARK: - Public

    func parseUsage() -> UsageEstimate {
        let telemetry = parseTelemetryLog()
        let sessions = parseSessionData()

        let allTimestamps = (telemetry.timestamps + sessions.timestamps).sorted()
        let model = telemetry.model ?? sessions.model

        return UsageEstimate(
            requestCount: telemetry.requestCount + sessions.requestCount,
            estimatedTokensInput: telemetry.inputTokens + sessions.inputTokens,
            estimatedTokensOutput: telemetry.outputTokens + sessions.outputTokens,
            requestTimestamps: allTimestamps,
            sessionCount: sessions.sessionCount,
            model: model
        )
    }

    // MARK: - Telemetry Log Parsing

    private struct TelemetryResult {
        var requestCount = 0
        var inputTokens = 0
        var outputTokens = 0
        var timestamps: [Date] = []
        var model: String?
    }

    private func parseTelemetryLog() -> TelemetryResult {
        let path = "\(configPath)/telemetry.log"
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            return TelemetryResult()
        }

        var result = TelemetryResult()

        for line in contents.components(separatedBy: .newlines) {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            // Look for span/event records that indicate an API call
            let name = json["name"] as? String ?? ""
            let isAPICall = name.contains("generate") || name.contains("api_call")
                || name.contains("request") || name.contains("llm")

            // Also check resource attributes for gemini-cli service
            let isGeminiSpan: Bool = {
                if let resource = json["resource"] as? [String: Any],
                   let attrs = resource["attributes"] as? [String: Any],
                   let svc = attrs["service.name"] as? String,
                   svc.contains("gemini")
                { return true }
                return false
            }()

            guard isAPICall || isGeminiSpan else { continue }

            result.requestCount += 1

            // Parse timestamp
            if let ts = json["timestamp"] as? String {
                if let date = isoFormatter.date(from: ts) ?? isoFallbackFormatter.date(from: ts) {
                    result.timestamps.append(date)
                }
            } else if let ts = json["startTimeUnixNano"] as? String, let nanos = UInt64(ts) {
                result.timestamps.append(Date(timeIntervalSince1970: Double(nanos) / 1_000_000_000))
            } else if let ts = json["time"] as? String {
                if let date = isoFormatter.date(from: ts) ?? isoFallbackFormatter.date(from: ts) {
                    result.timestamps.append(date)
                }
            }

            // Parse token counts from attributes if available
            if let attrs = json["attributes"] as? [String: Any] {
                if let input = attrs["gen_ai.usage.input_tokens"] as? Int {
                    result.inputTokens += input
                }
                if let output = attrs["gen_ai.usage.output_tokens"] as? Int {
                    result.outputTokens += output
                }
                if result.model == nil, let m = attrs["gen_ai.request.model"] as? String {
                    result.model = m
                }
            }
        }

        return result
    }

    // MARK: - Session Data Parsing

    private struct SessionResult {
        var requestCount = 0
        var inputTokens = 0
        var outputTokens = 0
        var timestamps: [Date] = []
        var sessionCount = 0
        var model: String?
    }

    private func parseSessionData() -> SessionResult {
        let fm = FileManager.default
        let tmpPath = "\(configPath)/tmp"

        guard let projectDirs = try? fm.contentsOfDirectory(atPath: tmpPath) else {
            return SessionResult()
        }

        var result = SessionResult()

        for projectDir in projectDirs {
            let chatsPath = "\(tmpPath)/\(projectDir)/chats"
            guard let chatFiles = try? fm.contentsOfDirectory(atPath: chatsPath) else {
                continue
            }

            for chatFile in chatFiles where chatFile.hasSuffix(".json") {
                result.sessionCount += 1
                let parsed = parseSessionFile("\(chatsPath)/\(chatFile)")
                result.requestCount += parsed.requests
                result.inputTokens += parsed.inputTokens
                result.outputTokens += parsed.outputTokens
                result.timestamps.append(contentsOf: parsed.timestamps)
                if result.model == nil { result.model = parsed.model }
            }
        }

        return result
    }

    private func parseSessionFile(
        _ path: String
    ) -> (requests: Int, inputTokens: Int, outputTokens: Int, timestamps: [Date], model: String?) {
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return (0, 0, 0, [], nil) }

        var requests = 0
        var inputTokens = 0
        var outputTokens = 0
        var timestamps: [Date] = []
        var model: String?

        // Parse messages array
        if let messages = json["messages"] as? [[String: Any]] {
            for message in messages {
                let role = message["role"] as? String
                guard role == "model" || role == "assistant" else { continue }

                requests += 1

                if let ts = message["timestamp"] as? String,
                   let date = isoFormatter.date(from: ts) ?? isoFallbackFormatter.date(from: ts)
                {
                    timestamps.append(date)
                }

                // Token usage if available
                if let usage = message["usage"] as? [String: Any] {
                    inputTokens += usage["prompt_tokens"] as? Int
                        ?? usage["input_tokens"] as? Int ?? 0
                    outputTokens += usage["completion_tokens"] as? Int
                        ?? usage["output_tokens"] as? Int ?? 0
                }

                if model == nil {
                    model = message["model"] as? String
                }
            }
        }

        // Check top-level model
        if model == nil {
            model = json["model"] as? String
        }

        return (requests, inputTokens, outputTokens, timestamps, model)
    }
}

// MARK: - Gemini Tier

/// Gemini has two distinct rate limit systems depending on auth mode.
/// OAuth uses Code Assist quotas; API Key uses Developer API quotas.
enum GeminiTier: Sendable {
    // OAuth (Code Assist) tiers
    case codeAssistFree          // Personal Gmail only: 60 RPM, 1000 RPD
    case codeAssistPro           // Google AI Pro: 120 RPM, 1500 RPD
    case codeAssistEnterprise    // Standard/Enterprise: 120 RPM, 2000 RPD
    case codeAssistUnknown       // Workspace/unknown tier: use Free limits conservatively

    // API Key (Developer API) tiers — limits are for gemini-2.5-pro
    case apiFree                 // 5 RPM, 100 RPD
    case apiPaidTier1            // 150 RPM, 1000 RPD
    case apiPaidTier2            // 1000 RPM, 10000 RPD

    var displayName: String {
        switch self {
        case .codeAssistFree: return "Free"
        case .codeAssistPro: return "Pro"
        case .codeAssistEnterprise: return "Enterprise"
        case .codeAssistUnknown: return "Google Account"
        case .apiFree: return "API Free"
        case .apiPaidTier1: return "API Paid"
        case .apiPaidTier2: return "API Tier 2"
        }
    }

    /// Representative rate limits (gemini-2.5-pro baseline).
    var limits: (rpm: Int, rpd: Int) {
        switch self {
        case .codeAssistFree: return (60, 1000)
        case .codeAssistPro: return (120, 1500)
        case .codeAssistEnterprise: return (120, 2000)
        case .codeAssistUnknown: return (60, 1000) // Conservative: use free limits
        case .apiFree: return (5, 100)
        case .apiPaidTier1: return (150, 1000)
        case .apiPaidTier2: return (1000, 10000)
        }
    }
}
