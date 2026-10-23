import Foundation
import CoreGraphics

enum Wing: String, Codable, CaseIterable, Identifiable {
    case neon
    case moving
    case crown
    case royal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .neon: return "Neon Halls"
        case .moving: return "Moving Chambers"
        case .crown: return "Crown Heights"
        case .royal: return "Royal Chambers"
        }
    }

    var backgroundName: String {
        switch self {
        case .neon: return "bg_neon_halls"
        case .moving: return "bg_moving_chambers"
        case .crown: return "bg_crown_heights"
        case .royal: return "bg_royal_chambers"
        }
    }

    var emblemName: String {
        switch self {
        case .neon: return "wing_neon_emblem"
        case .moving: return "wing_moving_emblem"
        case .crown: return "wing_crown_emblem"
        case .royal: return "royal_whip_emblem"
        }
    }

    var musicName: String {
        switch self {
        case .neon: return "music_neon_halls"
        case .moving: return "music_moving_chambers"
        case .crown: return "music_crown_heights"
        case .royal: return "music_royal_chambers"
        }
    }

    var isPremium: Bool { self == .royal }

    var campaignRange: ClosedRange<Int>? {
        switch self {
        case .neon: return 1...15
        case .moving: return 16...30
        case .crown: return 31...45
        case .royal: return nil
        }
    }

    var requiredCampaignLevelToUnlock: Int? {
        switch self {
        case .neon: return nil
        case .moving: return 15
        case .crown: return 30
        case .royal: return nil
        }
    }

    static var freeWings: [Wing] { [.neon, .moving, .crown] }
}

enum BallAppearance: String, Codable, CaseIterable, Identifiable {
    case limeSpark
    case mintPulse
    case violetArc

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .limeSpark: return "Lime Spark"
        case .mintPulse: return "Mint Pulse"
        case .violetArc: return "Violet Arc"
        }
    }

    var requiredStars: Int {
        switch self {
        case .limeSpark: return 0
        case .mintPulse: return 15
        case .violetArc: return 45
        }
    }

    var tint: UInt32 {
        switch self {
        case .limeSpark: return 0xB7FF00
        case .mintPulse: return 0x88F0C0
        case .violetArc: return 0xB39AF5
        }
    }
}

struct PlatformDefinition: Codable, Identifiable {
    var id: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

enum AnchorKind: String, Codable {
    case standard
    case moving
    case rotating
    case fragile
}

enum MoveAxis: String, Codable {
    case horizontal
    case vertical
}

struct AnchorDefinition: Codable, Identifiable {
    var id: String
    var type: AnchorKind
    var x: Double?
    var y: Double?
    var axis: MoveAxis?
    var amplitude: Double?
    var period: Double?
    var phase: Double?
    var centerX: Double?
    var centerY: Double?
    var radius: Double?

    func restPosition() -> CGPoint {
        if type == .rotating {
            let c = CGPoint(x: centerX ?? 0, y: centerY ?? 0)
            let r = radius ?? 0
            let p = phase ?? 0
            return CGPoint(x: c.x + CGFloat(r) * Foundation.cos(p), y: c.y + CGFloat(r) * Foundation.sin(p))
        }
        return CGPoint(x: x ?? 0, y: y ?? 0)
    }
}

struct CrystalDefinition: Codable, Identifiable {
    var id: String
    var x: Double
    var y: Double
    var position: CGPoint { CGPoint(x: x, y: y) }
}

struct CheckpointDefinition: Codable {
    var x: Double
    var y: Double
    var spawnX: Double
    var spawnY: Double
}

struct LaserDefinition: Codable, Identifiable {
    var id: String
    var x1: Double
    var y1: Double
    var x2: Double
    var y2: Double
    var activeDuration: Double
    var inactiveDuration: Double
    var phase: Double
}

struct SwitchDefinition: Codable, Identifiable {
    var id: String
    var x: Double
    var y: Double
    var doorId: String
}

struct DoorDefinition: Codable, Identifiable {
    var id: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

struct PointDef: Codable {
    var x: Double
    var y: Double
    var cg: CGPoint { CGPoint(x: x, y: y) }
}

struct LevelDefinition: Codable, Identifiable {
    var id: String
    var displayNumber: String
    var title: String
    var wing: Wing
    var worldHeight: Double
    var spawn: PointDef
    var attachmentLimit: Int
    var usesRoyalWhip: Bool
    var platforms: [PlatformDefinition]
    var anchors: [AnchorDefinition]
    var crystals: [CrystalDefinition]
    var checkpoint: CheckpointDefinition?
    var lasers: [LaserDefinition]
    var switches: [SwitchDefinition]
    var doors: [DoorDefinition]
    var portal: PointDef
    var isTrial: Bool?

    var trial: Bool { isTrial ?? false }

    var campaignIndex: Int? {
        if wing == .royal { return nil }
        return Int(displayNumber)
    }
}

struct LevelFile: Codable {
    var levels: [LevelDefinition]
}

struct LevelRecord: Codable, Equatable {
    var completed: Bool = false
    var crystalObjectiveEarned: Bool = false
    var noFallObjectiveEarned: Bool = false
    var attachmentObjectiveEarned: Bool = false
    var bestTime: Double? = nil
    var bestAttachmentCount: Int? = nil

    var starCount: Int {
        (crystalObjectiveEarned ? 1 : 0)
            + (noFallObjectiveEarned ? 1 : 0)
            + (attachmentObjectiveEarned ? 1 : 0)
    }
}

struct TutorialFlags: Codable, Equatable {
    var shownMovingAnchor = false
    var shownFragileAnchor = false
    var shownRotatingAnchor = false
    var shownLaser = false
    var shownSwitch = false
}

struct GameProgress: Codable {
    var schemaVersion: Int
    var campaign: [String: LevelRecord]
    var royal: [String: LevelRecord]
    var trial: LevelRecord
    var selectedAppearance: BallAppearance
    var lastSelectedWing: Wing
    var tutorialFlags: TutorialFlags

    static let currentSchema = 1

    static var empty: GameProgress {
        GameProgress(
            schemaVersion: currentSchema,
            campaign: [:],
            royal: [:],
            trial: LevelRecord(),
            selectedAppearance: .limeSpark,
            lastSelectedWing: .neon,
            tutorialFlags: TutorialFlags()
        )
    }

    func record(for level: LevelDefinition) -> LevelRecord {
        if level.trial { return trial }
        if level.wing == .royal { return royal[level.id] ?? LevelRecord() }
        return campaign[level.id] ?? LevelRecord()
    }

    var campaignStars: Int {
        campaign.values.reduce(0) { $0 + $1.starCount }
    }

    var completedCampaignCount: Int {
        campaign.values.filter(\.completed).count
    }

    func isCampaignLevelCompleted(_ id: String) -> Bool {
        campaign[id]?.completed == true
    }

    func highestCompletedCampaignNumber(in repository: LevelRepository) -> Int {
        repository.campaignLevels
            .filter { campaign[$0.id]?.completed == true }
            .compactMap { Int($0.displayNumber) }
            .max() ?? 0
    }
}

struct AppSettings: Codable, Equatable {
    var musicEnabled: Bool
    var musicVolume: Double
    var effectsEnabled: Bool
    var effectsVolume: Double
    var hapticsEnabled: Bool
    var reducedEffects: Bool

    static var defaultSettings: AppSettings {
        AppSettings(
            musicEnabled: true,
            musicVolume: 0.6,
            effectsEnabled: true,
            effectsVolume: 0.8,
            hapticsEnabled: true,
            reducedEffects: false
        )
    }
}

struct RunResults {
    var level: LevelDefinition
    var time: Double
    var attachments: Int
    var falls: Int
    var crystals: Int
    var crystalObjective: Bool
    var noFallObjective: Bool
    var attachmentObjective: Bool
    var isTrial: Bool
}
