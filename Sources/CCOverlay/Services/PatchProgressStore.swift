import Foundation
import Observation

/// Persists a companion roster, optional click treats, and token-earned progression.
/// Token totals begin at an in-memory baseline after each app launch, so only
/// new work observed while CC Overlay is open can advance the companion.
@Observable
@MainActor
final class PatchProgressStore {
    private struct StoredProgress: Codable {
        var growthTokens: Int
        var focusDayTokenCounts: [String: Int]
        var coins: Int
        var totalClicks: Int
        var totalFeeds: Int
        var feedCountsByPetID: [String: Int]
        var currentPetID: String?
        var ownedPetIDs: [String]
        var adoptionTickets: Int
        var lastTreatCollectedAt: Date?

        static let empty = StoredProgress(
            growthTokens: 0,
            focusDayTokenCounts: [:],
            coins: 0,
            totalClicks: 0,
            totalFeeds: 0,
            feedCountsByPetID: [:],
            currentPetID: nil,
            ownedPetIDs: [],
            adoptionTickets: 0,
            lastTreatCollectedAt: nil
        )

        enum CodingKeys: String, CodingKey {
            case growthTokens, focusDayTokenCounts, coins, totalClicks, totalFeeds, feedCountsByPetID
            case currentPetID, ownedPetIDs, adoptionTickets, lastTreatCollectedAt
        }

        init(
            growthTokens: Int,
            focusDayTokenCounts: [String: Int],
            coins: Int,
            totalClicks: Int,
            totalFeeds: Int,
            feedCountsByPetID: [String: Int],
            currentPetID: String?,
            ownedPetIDs: [String],
            adoptionTickets: Int,
            lastTreatCollectedAt: Date?
        ) {
            self.growthTokens = growthTokens
            self.focusDayTokenCounts = focusDayTokenCounts
            self.coins = coins
            self.totalClicks = totalClicks
            self.totalFeeds = totalFeeds
            self.feedCountsByPetID = feedCountsByPetID
            self.currentPetID = currentPetID
            self.ownedPetIDs = ownedPetIDs
            self.adoptionTickets = adoptionTickets
            self.lastTreatCollectedAt = lastTreatCollectedAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // Older percentage-XP and feedback-based records intentionally do
            // not convert to tokens: token progression begins from this launch.
            growthTokens = try container.decodeIfPresent(Int.self, forKey: .growthTokens) ?? 0
            focusDayTokenCounts = try container.decodeIfPresent([String: Int].self, forKey: .focusDayTokenCounts) ?? [:]
            coins = try container.decodeIfPresent(Int.self, forKey: .coins) ?? 0
            totalClicks = try container.decodeIfPresent(Int.self, forKey: .totalClicks) ?? 0
            totalFeeds = try container.decodeIfPresent(Int.self, forKey: .totalFeeds) ?? 0
            feedCountsByPetID = try container.decodeIfPresent([String: Int].self, forKey: .feedCountsByPetID) ?? [:]
            currentPetID = try container.decodeIfPresent(String.self, forKey: .currentPetID)
            ownedPetIDs = try container.decodeIfPresent([String].self, forKey: .ownedPetIDs) ?? []
            adoptionTickets = try container.decodeIfPresent(Int.self, forKey: .adoptionTickets) ?? 0
            lastTreatCollectedAt = try container.decodeIfPresent(Date.self, forKey: .lastTreatCollectedAt)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(growthTokens, forKey: .growthTokens)
            try container.encode(focusDayTokenCounts, forKey: .focusDayTokenCounts)
            try container.encode(coins, forKey: .coins)
            try container.encode(totalClicks, forKey: .totalClicks)
            try container.encode(totalFeeds, forKey: .totalFeeds)
            try container.encode(feedCountsByPetID, forKey: .feedCountsByPetID)
            try container.encodeIfPresent(currentPetID, forKey: .currentPetID)
            try container.encode(ownedPetIDs, forKey: .ownedPetIDs)
            try container.encode(adoptionTickets, forKey: .adoptionTickets)
            try container.encodeIfPresent(lastTreatCollectedAt, forKey: .lastTreatCollectedAt)
        }
    }

    private enum Key {
        static let progress = "patchProgress.v1"
    }

    /// Every observed 50K developer tokens earns one duplicate-free adoption
    /// ticket. Characters are therefore a record of real tool use, not clicks.
    static let adoptionTicketTokenCost = 50_000
    static let dailyFocusTokenTarget = 20_000
    /// Clicking earns one treat at a time; a proper meal costs several treats
    /// so care milestones remain satisfying instead of being instant unlocks.
    static let feedTreatCost = 5
    /// Treat collection intentionally stays a small, calm acknowledgement of
    /// the companion rather than a rapid-click currency loop.
    static let treatCollectionCooldown: TimeInterval = 0.8
    private static let retainedFocusDayCount = 400

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var stored: StoredProgress

    @ObservationIgnored private var observedTokenTotals: [String: Int] = [:]
    private var growthTokensThisLaunch = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        stored = Self.load(defaults: defaults, decoder: decoder)
    }

    var growthTokens: Int { stored.growthTokens }
    var sessionGrowthTokens: Int { growthTokensThisLaunch }
    var todayFocusTokens: Int { stored.focusDayTokenCounts[Self.focusDayKey(for: .now)] ?? 0 }
    var focusDayCount: Int {
        stored.focusDayTokenCounts.values.filter { $0 >= Self.dailyFocusTokenTarget }.count
    }
    var currentFocusStreak: Int { Self.focusStreak(in: stored.focusDayTokenCounts) }
    var treats: Int { stored.coins }
    var totalTreatsCollected: Int { stored.totalClicks }
    var totalFeeds: Int { stored.totalFeeds }
    func feedCount(for pet: CompanionPet) -> Int { stored.feedCountsByPetID[pet.rawValue, default: 0] }
    func care(for pet: CompanionPet) -> CompanionCare { CompanionCare(feedCount: feedCount(for: pet)) }
    var currentCare: CompanionCare { currentPet.map(care(for:)) ?? CompanionCare(feedCount: 0) }
    var careAccessory: CompanionCareAccessory? { currentCare.equippedAccessory }
    var growth: CompanionGrowth {
        CompanionGrowth(tokenCount: growthTokens, focusDayCount: focusDayCount)
    }
    var unlockedGear: [PatchGear] { growth.unlockedGear }
    var unlockedCrews: [CompanionCrew] { growth.unlockedCrews }
    var unlockedPets: [CompanionPet] {
        CompanionPet.allCases.filter { unlockedCrews.contains($0.crew) }
    }
    var currentPet: CompanionPet? { stored.currentPetID.flatMap(CompanionPet.init(rawValue:)) }
    var ownedPets: [CompanionPet] {
        CompanionPet.allCases.filter { stored.ownedPetIDs.contains($0.rawValue) }
    }
    var availablePets: [CompanionPet] {
        unlockedPets.filter { !stored.ownedPetIDs.contains($0.rawValue) }
    }
    var adoptionTickets: Int { stored.adoptionTickets }
    var canAdoptCompanion: Bool { !availablePets.isEmpty && adoptionTickets > 0 }
    var nextAdoptionTicketTokenCount: Int {
        (growthTokens / Self.adoptionTicketTokenCost + 1) * Self.adoptionTicketTokenCost
    }

    /// Records only positive token deltas after this running app first sees a
    /// source. A counter drop (e.g. a Claude window reset) becomes the next
    /// baseline and earns no tokens.
    func recordTokenUsage(
        observations: [CompanionTokenObservation],
        now: Date = Date()
    ) -> CompanionTokenGrowthResult {
        var tokensAdded = 0

        for observation in observations {
            let cumulativeTokens = max(observation.cumulativeTokens, 0)
            guard let previousTokens = observedTokenTotals[observation.sourceID] else {
                observedTokenTotals[observation.sourceID] = cumulativeTokens
                continue
            }

            observedTokenTotals[observation.sourceID] = cumulativeTokens
            tokensAdded += max(cumulativeTokens - previousTokens, 0)
        }

        guard tokensAdded > 0 else { return .none }

        let previousGrowth = growth
        let previousGear = Set(unlockedGear)
        let previousCrews = Set(unlockedCrews)
        let previousTicketMilestones = stored.growthTokens / Self.adoptionTicketTokenCost
        let focusDayKey = Self.focusDayKey(for: now)
        let wasFocusDayComplete = (stored.focusDayTokenCounts[focusDayKey] ?? 0) >= Self.dailyFocusTokenTarget

        stored.growthTokens += tokensAdded
        stored.focusDayTokenCounts[focusDayKey, default: 0] += tokensAdded
        Self.trimFocusDays(&stored.focusDayTokenCounts, now: now)
        growthTokensThisLaunch += tokensAdded

        let updatedGrowth = growth
        let newlyUnlockedCrews = updatedGrowth.unlockedCrews.filter { !previousCrews.contains($0) }
        let updatedTicketMilestones = stored.growthTokens / Self.adoptionTicketTokenCost
        let ticketsAdded = max(updatedTicketMilestones - previousTicketMilestones, 0)
        stored.adoptionTickets += ticketsAdded
        save()

        return CompanionTokenGrowthResult(
            tokensAdded: tokensAdded,
            newlyUnlockedGear: updatedGrowth.unlockedGear.filter { !previousGear.contains($0) },
            newlyUnlockedCrews: newlyUnlockedCrews,
            adoptionTicketsAdded: ticketsAdded,
            didCompleteFocusDay: !wasFocusDayComplete
                && (stored.focusDayTokenCounts[focusDayKey] ?? 0) >= Self.dailyFocusTokenTarget,
            didEvolve: updatedGrowth.evolution > previousGrowth.evolution
        )
    }

    /// Treats are optional, persistent interaction rewards. They never add
    /// developer tokens or unlock companions. A brief cooldown makes each
    /// interaction legible without turning the overlay into a clicker.
    func collectTreat(now: Date = Date()) -> TreatCollectionResult? {
        guard canCollectTreat(at: now) else { return nil }
        stored.coins += 1
        stored.totalClicks += 1
        stored.lastTreatCollectedAt = now
        save()
        return TreatCollectionResult(treatsAdded: 1, totalTreats: stored.coins)
    }

    func canCollectTreat(at now: Date = Date()) -> Bool {
        guard let lastCollectedAt = stored.lastTreatCollectedAt else { return true }
        // A clock correction should never leave care controls temporarily
        // unusable for an arbitrary amount of time.
        guard now >= lastCollectedAt else { return true }
        // Date arithmetic can land a fraction below an exact decimal boundary
        // (for example 0.7999999 for a scheduled 0.8-second interval).
        return now.timeIntervalSince(lastCollectedAt) >= Self.treatCollectionCooldown - 0.000_1
    }

    /// Treats build care with the current companion only. One care serving
    /// costs `feedTreatCost` treats; cosmetics never create developer tokens,
    /// adoption tickets, or roster unlocks.
    func feedCurrentCompanion(servingCount: Int = 1) -> CompanionFeedResult? {
        let treatsSpent = servingCount * Self.feedTreatCost
        guard let pet = currentPet, servingCount > 0, stored.coins >= treatsSpent else { return nil }
        let previousCare = care(for: pet)

        stored.coins -= treatsSpent
        stored.totalFeeds += servingCount
        stored.feedCountsByPetID[pet.rawValue, default: 0] += servingCount
        let updatedCare = care(for: pet)
        save()
        return CompanionFeedResult(
            treatsSpent: treatsSpent,
            totalFeeds: stored.totalFeeds,
            companionFeedCount: updatedCare.feedCount,
            care: updatedCare,
            newlyUnlockedAccessories: updatedCare.unlockedAccessories.filter {
                !previousCare.unlockedAccessories.contains($0)
            }
        )
    }

    /// Draws only from token-unlocked, unadopted pets, so an adoption ticket
    /// never produces a duplicate or bypasses a crew milestone.
    func drawCompanion(index: Int? = nil) -> CompanionDrawResult? {
        guard stored.adoptionTickets > 0, !availablePets.isEmpty else { return nil }
        let candidates = availablePets
        let selectedIndex = index.map { abs($0) % candidates.count }
            ?? Int.random(in: candidates.indices)
        let pet = candidates[selectedIndex]

        stored.adoptionTickets -= 1
        stored.ownedPetIDs.append(pet.rawValue)
        stored.currentPetID = pet.rawValue
        save()

        return CompanionDrawResult(
            pet: pet,
            remainingTickets: stored.adoptionTickets,
            completedCollection: availablePets.isEmpty && unlockedPets.count == CompanionPet.allCases.count
        )
    }

    func selectCompanion(_ pet: CompanionPet) {
        guard ownedPets.contains(pet) else { return }
        stored.currentPetID = pet.rawValue
        save()
    }

    private static func load(defaults: UserDefaults, decoder: JSONDecoder) -> StoredProgress {
        guard let data = defaults.data(forKey: Key.progress),
              let progress = try? decoder.decode(StoredProgress.self, from: data) else {
            return .empty
        }

        var ownedIDs = Set(progress.ownedPetIDs.compactMap(CompanionPet.init(rawValue:)))
        let currentPet = CompanionPet(rawValue: progress.currentPetID ?? "")
        if let currentPet { ownedIDs.insert(currentPet) }

        var feedCounts = progress.feedCountsByPetID.reduce(into: [String: Int]()) { result, entry in
            guard CompanionPet(rawValue: entry.key) != nil else { return }
            let count = max(entry.value, 0)
            if count > 0 { result[entry.key] = count }
        }
        // Records saved before per-companion care existed retain their earned
        // care on the companion that was active at migration time.
        if feedCounts.isEmpty, let currentPet, progress.totalFeeds > 0 {
            feedCounts[currentPet.rawValue] = max(progress.totalFeeds, 0)
        }

        return StoredProgress(
            growthTokens: max(progress.growthTokens, 0),
            focusDayTokenCounts: progress.focusDayTokenCounts.reduce(into: [:]) { result, entry in
                let tokens = max(entry.value, 0)
                if tokens > 0 { result[entry.key] = tokens }
            },
            coins: max(progress.coins, 0),
            totalClicks: max(progress.totalClicks, 0),
            totalFeeds: max(progress.totalFeeds, 0),
            feedCountsByPetID: feedCounts,
            currentPetID: currentPet?.rawValue,
            ownedPetIDs: CompanionPet.allCases.filter { ownedIDs.contains($0) }.map(\.rawValue),
            adoptionTickets: max(progress.adoptionTickets, 0),
            lastTreatCollectedAt: progress.lastTreatCollectedAt
        )
    }

    private func save() {
        guard let data = try? encoder.encode(stored) else { return }
        defaults.set(data, forKey: Key.progress)
    }

    private static func focusDayKey(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func focusStreak(
        in tokensByDay: [String: Int],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        var date = calendar.startOfDay(for: now)
        var streak = 0

        while tokensByDay[focusDayKey(for: date, calendar: calendar), default: 0] >= dailyFocusTokenTarget {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previousDay
        }
        return streak
    }

    private static func trimFocusDays(_ tokensByDay: inout [String: Int], now: Date) {
        let calendar = Calendar.current
        guard let oldestDate = calendar.date(byAdding: .day, value: -retainedFocusDayCount, to: now) else { return }
        let oldestKey = focusDayKey(for: oldestDate, calendar: calendar)
        tokensByDay = tokensByDay.filter { $0.key >= oldestKey }
    }
}
