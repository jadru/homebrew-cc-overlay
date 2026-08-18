import Foundation

/// A tiny, predictable one-second idle motion for Patch.
/// The animation cadence is deliberately independent from usage state so it
/// never suggests that a user's token consumption changed every second.
struct PatchMotion: Equatable, Sendable {
    static let frameInterval: TimeInterval = 1
    static let frameCount = 4
    static let still = PatchMotion(frameIndex: 0, verticalOffset: 0, rotationDegrees: 0, scale: 1)

    let frameIndex: Int
    let verticalOffset: Double
    let rotationDegrees: Double
    let scale: Double

    static func frame(at date: Date) -> PatchMotion {
        let elapsedFrames = Int(floor(date.timeIntervalSinceReferenceDate / frameInterval))
        let index = ((elapsedFrames % frameCount) + frameCount) % frameCount

        switch index {
        case 0:
            return PatchMotion(frameIndex: index, verticalOffset: 0, rotationDegrees: -0.35, scale: 1)
        case 1:
            return PatchMotion(frameIndex: index, verticalOffset: -1.0, rotationDegrees: 0.7, scale: 1.004)
        case 2:
            return PatchMotion(frameIndex: index, verticalOffset: -1.7, rotationDegrees: -0.55, scale: 1.006)
        default:
            return PatchMotion(frameIndex: index, verticalOffset: -0.7, rotationDegrees: 0.42, scale: 1.002)
        }
    }
}

/// A short transform-only action arc when the companion produces a treat.
/// It replaces sprite swapping so the reward feels like a physical action,
/// not a flash.
enum CompanionTreatReaction: Int, Equatable, Sendable {
    case idle
    case crouch
    case launch
    case settle

    var verticalOffset: Double {
        switch self {
        case .idle: 0
        case .crouch: 7
        // Expansion from the bottom already reads as a jump. Keeping the
        // origin fixed prevents the sprite from crossing the panel's top edge.
        case .launch: 0
        case .settle: -5
        }
    }

    var horizontalScale: Double {
        switch self {
        case .idle: 1
        case .crouch: 1.13
        case .launch: 0.9
        case .settle: 1.045
        }
    }

    var verticalScale: Double {
        switch self {
        case .idle: 1
        case .crouch: 0.85
        case .launch: 1.08
        case .settle: 0.975
        }
    }

    var rotationDegrees: Double {
        switch self {
        case .idle: 0
        case .crouch: -3
        case .launch: 4
        case .settle: -0.7
        }
    }
}

/// The reward text is deliberately expressed as data so its full enlarged
/// footprint can be tested against the fixed companion panel.
enum CompanionTreatRewardMotion: Int, CaseIterable, Equatable, Sendable {
    case appear
    case celebrate
    case settle

    var offset: CGSize {
        switch self {
        case .appear: CGSize(width: 0, height: PatchInteraction.companionRewardOriginY)
        case .celebrate: CGSize(width: 8, height: -68)
        case .settle: CGSize(width: -5, height: -70)
        }
    }

    var scale: CGFloat {
        switch self {
        case .appear: 0.35
        case .celebrate: 1.5
        case .settle: 1.12
        }
    }

    var rotationDegrees: Double {
        switch self {
        case .appear: -12
        case .celebrate: 10
        case .settle: -4
        }
    }

    /// Conservative pre-scaled axis-aligned footprint for the 25-point "+1",
    /// including its 10-degree rotation.
    static let maximumTextSize = CGSize(width: 44, height: 40)
}

/// A feed is the companion's signature acknowledgement: it leans in, takes a
/// bite, then settles. The values only affect transforms, so repeating care
/// interactions stay smooth in a small floating panel.
enum CompanionFeedReaction: Int, Equatable, Sendable {
    case idle
    case notice
    case nibble
    case pleased

    var verticalOffset: Double {
        switch self {
        case .idle: 0
        case .notice: -3
        case .nibble: 5
        case .pleased: -2
        }
    }

    var horizontalScale: Double {
        switch self {
        case .idle: 1
        case .notice: 1.018
        case .nibble: 1.052
        case .pleased: 1.018
        }
    }

    var verticalScale: Double {
        switch self {
        case .idle: 1
        case .notice: 1.018
        case .nibble: 0.925
        case .pleased: 1.028
        }
    }

    var rotationDegrees: Double {
        switch self {
        case .idle: 0
        case .notice: 0.5
        case .nibble: -1.1
        case .pleased: 0.25
        }
    }
}
