import Foundation

/// Every companion is equally likely when it is still unadopted. Personality
/// changes the visual identity only; no pet is stronger or better for usage.
enum CompanionPet: String, CaseIterable, Codable, Identifiable, Sendable {
    case dog
    case cat
    case otter
    case fox
    case penguin
    case owl
    case capybara
    case turtle
    case raccoon
    case axolotl
    case parrot
    case rabbit

    var id: String { rawValue }

    var name: String {
        switch self {
        case .dog: "Patch"
        case .cat: "Miso"
        case .otter: "Otto"
        case .fox: "Ember"
        case .penguin: "Nori"
        case .owl: "Ada"
        case .capybara: "Bean"
        case .turtle: "Taro"
        case .raccoon: "Cache"
        case .axolotl: "Loop"
        case .parrot: "Echo"
        case .rabbit: "Pip"
        }
    }

    var species: String {
        switch self {
        case .dog: "Ship-it dog"
        case .cat: "Focus cat"
        case .otter: "Debug otter"
        case .fox: "Refactor fox"
        case .penguin: "Release penguin"
        case .owl: "Night owl"
        case .capybara: "Pace capybara"
        case .turtle: "Steady turtle"
        case .raccoon: "Toolbelt raccoon"
        case .axolotl: "Learning axolotl"
        case .parrot: "Pair parrot"
        case .rabbit: "Sprint rabbit"
        }
    }

    var detail: String {
        switch self {
        case .dog: "A calm teammate who celebrates a clean ship."
        case .cat: "Protects deep-focus time with a quiet stare."
        case .otter: "Keeps a debugger float close at paw."
        case .fox: "Finds the smallest useful refactor first."
        case .penguin: "Carries release notes with steady feet."
        case .owl: "Keeps late-night work deliberate, not frantic."
        case .capybara: "Reminds the team that pace is a feature."
        case .turtle: "Makes slow, reliable progress feel good."
        case .raccoon: "Always has the right small tool nearby."
        case .axolotl: "Stays curious while the system is still learning."
        case .parrot: "Repeats the plan until everyone can explain it."
        case .rabbit: "Brings a bright start to a small, scoped sprint."
        }
    }

    var crew: CompanionCrew {
        switch self {
        case .dog, .cat, .otter, .fox:
            .starter
        case .penguin, .owl, .capybara, .turtle:
            .explorer
        case .raccoon, .axolotl, .parrot, .rabbit:
            .specialist
        }
    }

    var assetFilename: String { "companion-\(rawValue)" }
    var usesPatchAnimation: Bool { self == .dog }

    /// Wearables are complete, character-specific illustrations. A shared hat
    /// or shirt layer cannot follow twelve very different silhouettes, so an
    /// item is only rendered in the overlay once its fitted artwork exists.
    func fittedCareAssetFilename(for accessory: CompanionCareAccessory) -> String? {
        switch (self, accessory) {
        case (.turtle, .sproutCap): "companion-turtle-sprout-cap"
        default: nil
        }
    }
}

struct CompanionDrawResult: Equatable, Sendable {
    let pet: CompanionPet
    let remainingTickets: Int
    let completedCollection: Bool
}
