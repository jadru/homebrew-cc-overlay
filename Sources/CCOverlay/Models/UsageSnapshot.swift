import Foundation
import SwiftData

@Model
final class UsageSnapshot {
    var timestamp: Date
    var provider: String
    var intervalType: String
    var inputTokens: Int
    var outputTokens: Int
    var cacheCreationTokens: Int
    var cacheReadTokens: Int
    var totalCost: Double
    var projectName: String?

    init(
        timestamp: Date,
        provider: String,
        intervalType: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int,
        totalCost: Double,
        projectName: String? = nil
    ) {
        self.timestamp = timestamp
        self.provider = provider
        self.intervalType = intervalType
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.totalCost = totalCost
        self.projectName = projectName
    }
}
