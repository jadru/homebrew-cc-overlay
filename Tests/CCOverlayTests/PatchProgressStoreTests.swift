import XCTest
@testable import CCOverlay

@MainActor
final class PatchProgressStoreTests: XCTestCase {
    func testTokenUsageStartsAtLaunchBaselineAndNeverRewardsACounterReset() {
        let context = makeContext()
        let store = PatchProgressStore(defaults: context.defaults)
        let day = date(dayOffset: 0)

        XCTAssertEqual(store.recordTokenUsage(observations: [tokens("claude", 48_000)], now: day), .none)
        XCTAssertEqual(store.growthTokens, 0)

        let firstGrowth = store.recordTokenUsage(observations: [tokens("claude", 148_000)], now: day)
        XCTAssertEqual(firstGrowth.tokensAdded, 100_000)
        XCTAssertEqual(firstGrowth.newlyUnlockedGear, [.debugBandana, .duckSatchel])
        XCTAssertEqual(firstGrowth.newlyUnlockedCrews, [])
        XCTAssertEqual(firstGrowth.adoptionTicketsAdded, 2)
        XCTAssertTrue(firstGrowth.didCompleteFocusDay)
        XCTAssertTrue(firstGrowth.didEvolve)
        XCTAssertEqual(store.growthTokens, 100_000)
        XCTAssertEqual(store.focusDayCount, 1)
        XCTAssertEqual(store.sessionGrowthTokens, 100_000)

        XCTAssertEqual(store.recordTokenUsage(observations: [tokens("claude", 3_000)], now: day), .none)
        XCTAssertEqual(store.growthTokens, 100_000)

        let afterReset = store.recordTokenUsage(observations: [tokens("claude", 5_000)], now: day)
        XCTAssertEqual(afterReset.tokensAdded, 2_000)
        XCTAssertEqual(store.growthTokens, 102_000)
        XCTAssertEqual(store.sessionGrowthTokens, 102_000)
    }

    func testTokenSourcesMaintainIndependentBaselines() {
        let context = makeContext()
        let store = PatchProgressStore(defaults: context.defaults)
        let day = date(dayOffset: 0)

        XCTAssertEqual(
            store.recordTokenUsage(
                observations: [tokens("claude", 50_000), tokens("codex-account-a", 200_000)],
                now: day
            ),
            .none
        )
        let growth = store.recordTokenUsage(
            observations: [tokens("claude", 60_000), tokens("codex-account-a", 205_000)],
            now: day
        )

        XCTAssertEqual(growth.tokensAdded, 15_000)
        XCTAssertEqual(store.growthTokens, 15_000)
    }

    func testFocusDaysRequireDailyThresholdInsteadOfUnlimitedTokenBurn() {
        let context = makeContext()
        let store = PatchProgressStore(defaults: context.defaults)
        let firstDay = date(dayOffset: 0)

        _ = store.recordTokenUsage(observations: [tokens("claude", 0)], now: firstDay)
        let firstFocusDay = store.recordTokenUsage(observations: [tokens("claude", 100_000)], now: firstDay)
        XCTAssertTrue(firstFocusDay.didCompleteFocusDay)
        XCTAssertEqual(store.focusDayCount, 1)
        XCTAssertEqual(store.growth.evolution, .calibrated)
        XCTAssertFalse(store.unlockedCrews.contains(.explorer))

        _ = store.recordTokenUsage(
            observations: [tokens("claude", 120_000)],
            now: date(dayOffset: 1)
        )
        let thirdDay = store.recordTokenUsage(
            observations: [tokens("claude", 140_000)],
            now: date(dayOffset: 2)
        )
        XCTAssertTrue(thirdDay.didCompleteFocusDay)
        XCTAssertEqual(store.focusDayCount, 3)
        XCTAssertEqual(store.unlockedCrews, [.starter, .explorer])
        XCTAssertEqual(thirdDay.newlyUnlockedCrews, [.explorer])
        XCTAssertEqual(thirdDay.adoptionTicketsAdded, 0)
    }

    func testGrowthTokensAndFocusDaysPersistButLaunchBaselinesDoNot() {
        let context = makeContext()
        let store = PatchProgressStore(defaults: context.defaults)
        let day = date(dayOffset: 0)

        _ = store.recordTokenUsage(observations: [tokens("claude", 10_000)], now: day)
        _ = store.recordTokenUsage(observations: [tokens("claude", 60_000)], now: day)
        XCTAssertEqual(store.growthTokens, 50_000)
        XCTAssertEqual(store.focusDayCount, 1)

        let reloaded = PatchProgressStore(defaults: context.defaults)
        XCTAssertEqual(reloaded.growthTokens, 50_000)
        XCTAssertEqual(reloaded.focusDayCount, 1)
        XCTAssertEqual(reloaded.sessionGrowthTokens, 0)
        XCTAssertEqual(reloaded.recordTokenUsage(observations: [tokens("claude", 91_000)], now: day), .none)
        XCTAssertEqual(reloaded.growthTokens, 50_000)
    }

    func testLegacyFeedbackAndPercentagePointsDoNotBecomeTokens() {
        let context = makeContext()
        let legacy = #"{"trustPoints":140,"experiencePoints":140,"currentPetID":"dog","ownedPetIDs":["dog"],"adoptionTickets":0}"#
        context.defaults.set(Data(legacy.utf8), forKey: "patchProgress.v1")

        let store = PatchProgressStore(defaults: context.defaults)
        XCTAssertEqual(store.growthTokens, 0)
        XCTAssertEqual(store.focusDayCount, 0)
        XCTAssertEqual(store.currentPet, .dog)
        XCTAssertEqual(store.ownedPets, [.dog])
    }

    func testTreatsComeOnlyFromClicksAndFeedWithoutUnlockingPets() {
        let context = makeContext()
        let store = PatchProgressStore(defaults: context.defaults)
        let start = Date(timeIntervalSince1970: 1_750_100_000)

        for expectedTotal in 1...3 {
            let result = tryUnwrap(
                store.collectTreat(
                    now: start.addingTimeInterval(Double(expectedTotal - 1) * PatchProgressStore.treatCollectionCooldown)
                )
            )
            XCTAssertEqual(result.treatsAdded, 1)
            XCTAssertEqual(result.totalTreats, expectedTotal)
        }
        XCTAssertEqual(store.growthTokens, 0)
        XCTAssertEqual(store.totalTreatsCollected, 3)
        XCTAssertFalse(store.canAdoptCompanion)
        XCTAssertNil(store.feedCurrentCompanion())
    }

    func testTreatCollectionHasACalmCooldownInsteadOfRewardingRapidClicks() {
        let context = makeContext()
        let store = PatchProgressStore(defaults: context.defaults)
        let start = Date(timeIntervalSince1970: 1_750_100_000)

        XCTAssertNotNil(store.collectTreat(now: start))
        XCTAssertNil(store.collectTreat(now: start.addingTimeInterval(0.2)))
        XCTAssertEqual(store.treats, 1)
        XCTAssertEqual(store.totalTreatsCollected, 1)

        XCTAssertNotNil(
            store.collectTreat(
                now: start.addingTimeInterval(PatchProgressStore.treatCollectionCooldown)
            )
        )
        XCTAssertEqual(store.treats, 2)
    }

    func testTokenMilestonesAwardAdoptionTicketsAndTreatsFeedTheCurrentPet() {
        let context = makeContext()
        let store = PatchProgressStore(defaults: context.defaults)
        let day = date(dayOffset: 0)
        _ = store.recordTokenUsage(observations: [tokens("claude", 0)], now: day)
        let growth = store.recordTokenUsage(observations: [tokens("claude", 100_000)], now: day)

        XCTAssertEqual(growth.adoptionTicketsAdded, 2)
        XCTAssertEqual(store.adoptionTickets, 2)
        let draw = tryUnwrap(store.drawCompanion(index: 0))
        XCTAssertEqual(draw.pet, .dog)

        XCTAssertTrue(store.canAdoptCompanion)
        collectTreats(PatchProgressStore.feedTreatCost - 1, into: store)
        XCTAssertNil(store.feedCurrentCompanion())

        collectTreats(1, into: store, startingAt: Date(timeIntervalSince1970: 1_750_200_000))
        let feed = tryUnwrap(store.feedCurrentCompanion())
        XCTAssertEqual(feed.treatsSpent, PatchProgressStore.feedTreatCost)
        XCTAssertEqual(feed.totalFeeds, 1)
        XCTAssertEqual(feed.companionFeedCount, 1)
        XCTAssertEqual(feed.care.title, "New friend")
        XCTAssertTrue(feed.newlyUnlockedAccessories.isEmpty)
        XCTAssertEqual(store.treats, 0)
        XCTAssertEqual(store.adoptionTickets, 1)
    }

    func testTreatCareGrowsEachCompanionAndUnlocksItsAccessories() {
        let context = makeContext()
        let store = PatchProgressStore(defaults: context.defaults)
        _ = store.recordTokenUsage(observations: [tokens("claude", 0)])
        _ = store.recordTokenUsage(observations: [tokens("claude", 100_000)])
        let dog = tryUnwrap(store.drawCompanion(index: 0))
        XCTAssertEqual(dog.pet, .dog)

        collectTreats(120 * PatchProgressStore.feedTreatCost, into: store)

        let firstMilestone = tryUnwrap(store.feedCurrentCompanion(servingCount: 10))
        XCTAssertEqual(firstMilestone.care.title, "Trusted")
        XCTAssertEqual(firstMilestone.newlyUnlockedAccessories, [.developerBandana])
        XCTAssertEqual(store.careAccessory, .developerBandana)

        let secondMilestone = tryUnwrap(store.feedCurrentCompanion(servingCount: 30))
        XCTAssertEqual(secondMilestone.care.title, "Growing close")
        XCTAssertEqual(secondMilestone.newlyUnlockedAccessories, [.sproutCap])

        let thirdMilestone = tryUnwrap(store.feedCurrentCompanion(servingCount: 80))
        XCTAssertEqual(thirdMilestone.companionFeedCount, 120)
        XCTAssertEqual(thirdMilestone.care.title, "Cozy team")
        XCTAssertEqual(thirdMilestone.newlyUnlockedAccessories, [.cozyHoodie])
        XCTAssertEqual(store.careAccessory, .cozyHoodie)

        let cat = tryUnwrap(store.drawCompanion(index: 0))
        XCTAssertEqual(cat.pet, .cat)
        XCTAssertEqual(store.currentCare.feedCount, 0)
        XCTAssertNil(store.careAccessory)

        store.selectCompanion(.dog)
        XCTAssertEqual(store.currentCare.feedCount, 120)
        XCTAssertEqual(store.careAccessory, .cozyHoodie)
    }

    func testGearWorkshopAndEvolutionRequireDeveloperTokensAndFocusDays() {
        XCTAssertEqual(CompanionGrowth(tokenCount: 0).workshop, .starter)
        XCTAssertEqual(CompanionGrowth(tokenCount: 25_000).workshop, .starter)
        XCTAssertEqual(CompanionGrowth(tokenCount: 100_000, focusDayCount: 3).workshop, .debug)
        XCTAssertEqual(CompanionGrowth(tokenCount: 300_000, focusDayCount: 5).workshop, .night)
        XCTAssertEqual(CompanionGrowth(tokenCount: 750_000, focusDayCount: 10).workshop, .ship)
        XCTAssertEqual(CompanionGrowth(tokenCount: 750_000).unlockedGear, PatchGear.allCases)
        XCTAssertEqual(CompanionGrowth(tokenCount: 50_000, focusDayCount: 0).evolution, .rookie)
        XCTAssertEqual(CompanionGrowth(tokenCount: 50_000, focusDayCount: 1).evolution, .calibrated)
        XCTAssertEqual(CompanionGrowth(tokenCount: 250_000, focusDayCount: 5).evolution, .evolved)
        XCTAssertEqual(CompanionGrowth(tokenCount: 1_000_000, focusDayCount: 20).evolution, .legendary)
    }

    func testTokenMilestonesUnlockCrewsAndAwardRecurringTicketsWithoutDuplicates() {
        let context = makeContext()
        let store = PatchProgressStore(defaults: context.defaults)
        let firstDay = date(dayOffset: 0)

        XCTAssertEqual(store.unlockedPets, CompanionCrew.starter.pets)
        XCTAssertEqual(store.availablePets, CompanionCrew.starter.pets)

        _ = store.recordTokenUsage(observations: [tokens("claude", 0)], now: firstDay)
        _ = store.recordTokenUsage(observations: [tokens("claude", 50_000)], now: firstDay)
        let first = tryUnwrap(store.drawCompanion(index: 0))
        XCTAssertEqual(first.pet, .dog)

        for dayOffset in 1..<10 {
            _ = store.recordTokenUsage(
                observations: [tokens("claude", (dayOffset + 1) * 50_000)],
                now: date(dayOffset: dayOffset)
            )
        }
        XCTAssertEqual(store.growthTokens, 500_000)
        XCTAssertEqual(store.focusDayCount, 10)
        XCTAssertEqual(store.adoptionTickets, 9)
        XCTAssertEqual(store.unlockedPets.count, 12)

        let second = tryUnwrap(store.drawCompanion(index: 0))
        XCTAssertNotEqual(second.pet, first.pet)
        XCTAssertEqual(Set(store.ownedPets).count, 2)
        XCTAssertFalse(store.availablePets.contains(first.pet))
        XCTAssertFalse(store.availablePets.contains(second.pet))
    }

    func testEveryGearAndWorkshopMapsToDedicatedPixelArtwork() {
        XCTAssertEqual(PatchGear.debugBandana.assetFilename, "patch-gear-debug-bandana")
        XCTAssertEqual(PatchGear.duckSatchel.assetFilename, "patch-gear-duck-satchel")
        XCTAssertEqual(PatchGear.nightCollar.assetFilename, "patch-gear-night-collar")
        XCTAssertEqual(PatchGear.shipCape.assetFilename, "patch-gear-ship-cape")
        XCTAssertEqual(PatchWorkshop.ship.assetFilename, "patch-workshop-ship")
        XCTAssertEqual(CompanionCareAccessory.developerBandana.assetFilename, "care-bandana-v2")
        XCTAssertEqual(CompanionCareAccessory.sproutCap.assetFilename, "care-sprout-cap")
        XCTAssertEqual(CompanionCareAccessory.cozyHoodie.assetFilename, "care-hoodie")
        XCTAssertEqual(CompanionCareAccessory.starCrown.assetFilename, "care-star-crown")
        XCTAssertEqual(
            CompanionPet.turtle.fittedCareAssetFilename(for: .sproutCap),
            "companion-turtle-sprout-cap"
        )
        XCTAssertNil(CompanionPet.turtle.fittedCareAssetFilename(for: .starCrown))
    }

    func testFirstCompanionIsDrawnFromTheStarterPoolWithoutADefaultPet() {
        let context = makeContext()
        let store = PatchProgressStore(defaults: context.defaults)

        XCTAssertNil(store.currentPet)
        XCTAssertEqual(store.adoptionTickets, 0)
        XCTAssertEqual(store.availablePets, CompanionCrew.starter.pets)

        _ = store.recordTokenUsage(observations: [tokens("claude", 0)])
        _ = store.recordTokenUsage(observations: [tokens("claude", 50_000)])
        XCTAssertEqual(store.adoptionTickets, 1)

        let draw = tryUnwrap(store.drawCompanion(index: 2))
        XCTAssertEqual(draw.pet, .otter)
        XCTAssertEqual(store.currentPet, .otter)
        XCTAssertEqual(store.ownedPets, [.otter])
        XCTAssertEqual(store.adoptionTickets, 0)
        XCTAssertFalse(store.availablePets.contains(.otter))
    }

    func testOnlyAdoptedPetsCanBecomeCurrentCompanion() {
        let context = makeContext()
        let store = PatchProgressStore(defaults: context.defaults)
        _ = store.recordTokenUsage(observations: [tokens("claude", 0)])
        _ = store.recordTokenUsage(observations: [tokens("claude", 50_000)])
        _ = store.drawCompanion(index: 1)

        store.selectCompanion(.dog)
        XCTAssertEqual(store.currentPet, .cat)

        store.selectCompanion(.cat)
        XCTAssertEqual(store.currentPet, .cat)
    }

    func testEveryCompanionMapsToItsOwnSpriteAssetAndCrew() {
        XCTAssertEqual(CompanionPet.allCases.count, 12)
        XCTAssertEqual(CompanionPet.dog.assetFilename, "companion-dog")
        XCTAssertEqual(CompanionPet.axolotl.assetFilename, "companion-axolotl")
        XCTAssertEqual(CompanionPet.rabbit.assetFilename, "companion-rabbit")
        XCTAssertEqual(Set(CompanionPet.allCases.map(\.assetFilename)).count, 12)
        XCTAssertEqual(CompanionCrew.starter.pets.count, 4)
        XCTAssertEqual(CompanionCrew.explorer.pets.count, 4)
        XCTAssertEqual(CompanionCrew.specialist.pets.count, 4)
    }

    private func tokens(_ sourceID: String, _ count: Int) -> CompanionTokenObservation {
        CompanionTokenObservation(sourceID: sourceID, cumulativeTokens: count)
    }

    private func date(dayOffset: Int) -> Date {
        let base = Date(timeIntervalSince1970: 1_750_000_000)
        return Calendar(identifier: .gregorian).date(byAdding: .day, value: dayOffset, to: base)!
    }

    private func collectTreats(
        _ count: Int,
        into store: PatchProgressStore,
        startingAt start: Date = Date(timeIntervalSince1970: 1_750_100_000)
    ) {
        for index in 0..<count {
            XCTAssertNotNil(
                store.collectTreat(
                    now: start.addingTimeInterval(Double(index) * PatchProgressStore.treatCollectionCooldown)
                )
            )
        }
    }

    private func makeContext() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "PatchProgressStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return (defaults, suiteName)
    }

    private func tryUnwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) -> T {
        guard let value else {
            XCTFail("Expected a value", file: file, line: line)
            fatalError("Unreachable after XCTFail")
        }
        return value
    }
}
