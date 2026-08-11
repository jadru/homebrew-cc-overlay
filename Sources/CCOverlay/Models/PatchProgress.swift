import Foundation

/// Permanent gear is unlocked by cumulative developer tokens observed after
/// launch. Rate-limit resets and historical usage can never grant progress.
enum PatchGear: String, CaseIterable, Codable, Identifiable, Sendable {
    case debugBandana
    case duckSatchel
    case nightCollar
    case shipCape

    var id: String { rawValue }

    var title: String {
        switch self {
        case .debugBandana: "Debugger bandana"
        case .duckSatchel: "Duck satchel"
        case .nightCollar: "Night collar"
        case .shipCape: "Ship-it cape"
        }
    }

    var detail: String {
        switch self {
        case .debugBandana: "For carefully scoped debugging sessions."
        case .duckSatchel: "For problems worth explaining out loud."
        case .nightCollar: "For a calm, well-paced late shift."
        case .shipCape: "For a finished decision that can ship."
        }
    }

    var symbolName: String {
        switch self {
        case .debugBandana: "ladybug.fill"
        case .duckSatchel: "backpack.fill"
        case .nightCollar: "moon.stars.fill"
        case .shipCape: "checkmark.seal.fill"
        }
    }

    var assetFilename: String { "patch-gear-\(rawValue.kebabCased)" }

    var unlockTokenCount: Int {
        switch self {
        case .debugBandana: 25_000
        case .duckSatchel: 100_000
        case .nightCollar: 300_000
        case .shipCape: 750_000
        }
    }

}

/// Treats build a relationship with each adopted companion independently from
/// developer-token progression. Reaching a care milestone equips the newest
/// pixel accessory automatically, so feeding always has a visible result.
enum CompanionCareAccessory: String, CaseIterable, Codable, Identifiable, Sendable {
    case developerBandana
    case sproutCap
    case cozyHoodie
    case starCrown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .developerBandana: "Developer bandana"
        case .sproutCap: "Sprout cap"
        case .cozyHoodie: "Cozy hoodie"
        case .starCrown: "Star crown"
        }
    }

    var careTitle: String {
        switch self {
        case .developerBandana: "Trusted"
        case .sproutCap: "Growing close"
        case .cozyHoodie: "Cozy team"
        case .starCrown: "Star companion"
        }
    }

    var detail: String {
        switch self {
        case .developerBandana: "A sign that the pair has found its rhythm."
        case .sproutCap: "A tiny garden for steady care."
        case .cozyHoodie: "For long, calm building sessions."
        case .starCrown: "For a companion raised with real care."
        }
    }

    var symbolName: String {
        switch self {
        case .developerBandana: "chevron.left.forwardslash.chevron.right"
        case .sproutCap: "leaf.fill"
        case .cozyHoodie: "tshirt.fill"
        case .starCrown: "crown.fill"
        }
    }

    var assetFilename: String {
        switch self {
        // This is a fitted wearable sprite, rather than a full-size concept
        // image that could cover the companion beneath it.
        case .developerBandana: "care-bandana-v2"
        case .sproutCap: "care-sprout-cap"
        case .cozyHoodie: "care-hoodie"
        case .starCrown: "care-star-crown"
        }
    }

    var unlockFeedCount: Int {
        switch self {
        case .developerBandana: 10
        case .sproutCap: 40
        case .cozyHoodie: 120
        case .starCrown: 300
        }
    }
}

struct CompanionCare: Equatable, Sendable {
    let feedCount: Int

    init(feedCount: Int) {
        self.feedCount = max(feedCount, 0)
    }

    var unlockedAccessories: [CompanionCareAccessory] {
        CompanionCareAccessory.allCases.filter { feedCount >= $0.unlockFeedCount }
    }

    var equippedAccessory: CompanionCareAccessory? { unlockedAccessories.last }

    var title: String { equippedAccessory?.careTitle ?? "New friend" }

    var nextAccessory: CompanionCareAccessory? {
        CompanionCareAccessory.allCases.first { feedCount < $0.unlockFeedCount }
    }

    var feedsUntilNextAccessory: Int? {
        nextAccessory.map { $0.unlockFeedCount - feedCount }
    }
}

/// A single wide workshop composition keeps every companion on the same pixel
/// floor line while permanent decorations progress with developer tokens.
enum PatchWorkshop: String, CaseIterable, Equatable, Sendable {
    case starter
    case debug
    case night
    case ship

    var assetFilename: String { "patch-workshop-\(rawValue)" }

    static func current(for unlockedGear: [PatchGear]) -> PatchWorkshop {
        if unlockedGear.contains(.shipCape) { return .ship }
        if unlockedGear.contains(.nightCollar) { return .night }
        if unlockedGear.contains(.duckSatchel) { return .debug }
        return .starter
    }
}

/// Token milestones unlock whole companion cohorts. A ticket still draws one
/// unadopted companion uniformly; it never creates a duplicate.
enum CompanionCrew: String, CaseIterable, Codable, Identifiable, Sendable {
    case starter
    case explorer
    case specialist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .starter: "Starter crew"
        case .explorer: "Explorer crew"
        case .specialist: "Specialist crew"
        }
    }

    var unlockTokenCount: Int {
        switch self {
        case .starter: 0
        case .explorer: 100_000
        case .specialist: 500_000
        }
    }

    var minimumFocusDays: Int {
        switch self {
        case .starter: 0
        case .explorer: 3
        case .specialist: 10
        }
    }

    func isUnlocked(tokenCount: Int, focusDayCount: Int) -> Bool {
        tokenCount >= unlockTokenCount && focusDayCount >= minimumFocusDays
    }

    var unlockDescription: String {
        if minimumFocusDays == 0 { return "Available from the start" }
        return "\(NumberFormatting.formatTokenCount(unlockTokenCount)) developer tokens · \(minimumFocusDays) focus days"
    }

    var pets: [CompanionPet] {
        CompanionPet.allCases.filter { $0.crew == self }
    }
}

/// Evolution has clear token thresholds, so users can see meaningful long-term
/// change without turning clicks into the primary progression mechanic.
enum CompanionEvolution: Int, CaseIterable, Comparable, Sendable {
    case rookie
    case calibrated
    case evolved
    case legendary

    static func < (lhs: CompanionEvolution, rhs: CompanionEvolution) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .rookie: "Rookie form"
        case .calibrated: "Calibrated form"
        case .evolved: "Evolved form"
        case .legendary: "Legend form"
        }
    }

    var unlockTokenCount: Int {
        switch self {
        case .rookie: 0
        case .calibrated: 50_000
        case .evolved: 250_000
        case .legendary: 1_000_000
        }
    }

    var minimumFocusDays: Int {
        switch self {
        case .rookie: 0
        case .calibrated: 1
        case .evolved: 5
        case .legendary: 20
        }
    }

    func isUnlocked(tokenCount: Int, focusDayCount: Int) -> Bool {
        tokenCount >= unlockTokenCount && focusDayCount >= minimumFocusDays
    }

    static func current(for tokenCount: Int, focusDayCount: Int) -> CompanionEvolution {
        allCases.last(where: { $0.isUnlocked(tokenCount: tokenCount, focusDayCount: focusDayCount) }) ?? .rookie
    }

    var next: CompanionEvolution? {
        CompanionEvolution(rawValue: rawValue + 1)
    }
}

/// Progress is a record of developer tokens observed after launch. It is
/// intentionally distinct from optional treat interactions, account history,
/// and rate resets.
struct CompanionGrowth: Equatable, Sendable {
    let tokenCount: Int
    let focusDayCount: Int

    init(tokenCount: Int, focusDayCount: Int = 0) {
        self.tokenCount = max(tokenCount, 0)
        self.focusDayCount = max(focusDayCount, 0)
    }

    private static let levelThresholds = [0, 10_000, 25_000, 50_000, 100_000, 250_000, 500_000, 1_000_000, 2_000_000]
    private static let titles = [
        "New teammate",
        "First prompt",
        "Debug buddy",
        "Focus regular",
        "Crew scout",
        "Workflow keeper",
        "Veteran builder",
        "Master companion",
        "Studio icon",
    ]

    var level: Int {
        Self.levelThresholds.lastIndex(where: { tokenCount >= $0 }).map { $0 + 1 } ?? 1
    }

    var title: String { Self.titles[min(level - 1, Self.titles.count - 1)] }

    var nextLevelTokenCount: Int? {
        Self.levelThresholds.dropFirst().first(where: { tokenCount < $0 })
    }

    var progressToNextLevel: Double {
        guard let next = nextLevelTokenCount else { return 1 }
        let currentThreshold = Self.levelThresholds[level - 1]
        let required = max(next - currentThreshold, 1)
        return min(max(Double(tokenCount - currentThreshold) / Double(required), 0), 1)
    }

    var evolution: CompanionEvolution {
        CompanionEvolution.current(for: tokenCount, focusDayCount: focusDayCount)
    }
    var nextEvolutionTokenCount: Int? { evolution.next?.unlockTokenCount }

    var unlockedGear: [PatchGear] {
        PatchGear.allCases.filter { tokenCount >= $0.unlockTokenCount }
    }

    var unlockedCrews: [CompanionCrew] {
        CompanionCrew.allCases.filter {
            $0.isUnlocked(tokenCount: tokenCount, focusDayCount: focusDayCount)
        }
    }

    var workshop: PatchWorkshop { PatchWorkshop.current(for: unlockedGear) }
}

/// A cumulative reading from one local source, such as Claude's current window
/// or a selected Codex account's lifetime total.
struct CompanionTokenObservation: Equatable, Sendable {
    let sourceID: String
    let cumulativeTokens: Int
}

struct CompanionTokenGrowthResult: Equatable, Sendable {
    let tokensAdded: Int
    let newlyUnlockedGear: [PatchGear]
    let newlyUnlockedCrews: [CompanionCrew]
    let adoptionTicketsAdded: Int
    let didCompleteFocusDay: Bool
    let didEvolve: Bool

    static let none = CompanionTokenGrowthResult(
        tokensAdded: 0,
        newlyUnlockedGear: [],
        newlyUnlockedCrews: [],
        adoptionTicketsAdded: 0,
        didCompleteFocusDay: false,
        didEvolve: false
    )
}

struct TreatCollectionResult: Equatable, Sendable {
    let treatsAdded: Int
    let totalTreats: Int
}

struct CompanionFeedResult: Equatable, Sendable {
    let treatsSpent: Int
    let totalFeeds: Int
    let companionFeedCount: Int
    let care: CompanionCare
    let newlyUnlockedAccessories: [CompanionCareAccessory]
}

private extension String {
    var kebabCased: String {
        unicodeScalars.enumerated().reduce(into: "") { result, element in
            let scalar = element.element
            if CharacterSet.uppercaseLetters.contains(scalar), element.offset > 0 {
                result.append("-")
            }
            result.unicodeScalars.append(scalar)
        }
        .lowercased()
    }
}
