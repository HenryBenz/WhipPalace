import Foundation

struct LevelValidationError: Error, Equatable {
    var message: String
}

final class LevelRepository {
    private(set) var campaignLevels: [LevelDefinition] = []
    private(set) var royalLevels: [LevelDefinition] = []
    private(set) var trialLevel: LevelDefinition?

    var allLevels: [LevelDefinition] {
        campaignLevels + royalLevels + (trialLevel.map { [$0] } ?? [])
    }

    func loadBundled() throws {
        let neon = try loadFile(named: "neon_halls")
        let moving = try loadFile(named: "moving_chambers")
        let crown = try loadFile(named: "crown_heights")
        let royal = try loadFile(named: "royal_chambers")
        let trialFile = try loadFile(named: "royal_trial")

        try validateWing(neon, wing: .neon, count: 15, start: 1)
        try validateWing(moving, wing: .moving, count: 15, start: 16)
        try validateWing(crown, wing: .crown, count: 15, start: 31)
        try validateWing(royal, wing: .royal, count: 15, start: 1)
        guard trialFile.count == 1 else {
            throw LevelValidationError(message: "The bundled level files could not be loaded.")
        }
        var trial = trialFile[0]
        trial.isTrial = true
        try validateLevel(trial)

        campaignLevels = neon + moving + crown
        royalLevels = royal
        trialLevel = trial
    }

    func level(withID id: String) -> LevelDefinition? {
        allLevels.first { $0.id == id }
    }

    func campaignLevel(number: Int) -> LevelDefinition? {
        campaignLevels.first { Int($0.displayNumber) == number }
    }

    func levels(for wing: Wing) -> [LevelDefinition] {
        switch wing {
        case .royal: return royalLevels
        default: return campaignLevels.filter { $0.wing == wing }
        }
    }

    func nextCampaignLevel(after level: LevelDefinition) -> LevelDefinition? {
        guard let n = Int(level.displayNumber), n < 45 else { return nil }
        return campaignLevel(number: n + 1)
    }

    func nextRoyalLevel(after level: LevelDefinition) -> LevelDefinition? {
        guard level.wing == .royal, let n = Int(level.displayNumber.replacingOccurrences(of: "R", with: "")), n < 15 else {
            return nil
        }
        return royalLevels.first { $0.displayNumber == "R\(n + 1)" || $0.displayNumber == "\(n + 1)" }
    }

    private func loadFile(named name: String) throws -> [LevelDefinition] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw LevelValidationError(message: "The bundled level files could not be loaded.")
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw LevelValidationError(message: "The bundled level files could not be loaded.")
        }
        do {
            return try JSONDecoder().decode(LevelFile.self, from: data).levels
        } catch {
            throw LevelValidationError(message: "The bundled level files could not be loaded.")
        }
    }

    private func validateWing(_ levels: [LevelDefinition], wing: Wing, count: Int, start: Int) throws {
        guard levels.count == count else {
            throw LevelValidationError(message: "The bundled level files could not be loaded.")
        }
        for (index, level) in levels.enumerated() {
            guard level.wing == wing else {
                throw LevelValidationError(message: "The bundled level files could not be loaded.")
            }
            try validateLevel(level)
            if wing != .royal {
                guard Int(level.displayNumber) == start + index else {
                    throw LevelValidationError(message: "The bundled level files could not be loaded.")
                }
            }
        }
    }

    private func validateLevel(_ level: LevelDefinition) throws {
        guard level.crystals.count == 3 else {
            throw LevelValidationError(message: "The bundled level files could not be loaded.")
        }
        guard level.worldHeight > 0, level.attachmentLimit > 0 else {
            throw LevelValidationError(message: "The bundled level files could not be loaded.")
        }
        guard !level.platforms.isEmpty, !level.anchors.isEmpty else {
            throw LevelValidationError(message: "The bundled level files could not be loaded.")
        }
        let isTutorial = ["N01", "N02", "N03"].contains(level.id)
        if !isTutorial && !level.trial && level.checkpoint == nil {
            throw LevelValidationError(message: "The bundled level files could not be loaded.")
        }
        for laser in level.lasers {
            guard laser.inactiveDuration >= 1.4 else {
                throw LevelValidationError(message: "The bundled level files could not be loaded.")
            }
            let dx = laser.x2 - laser.x1
            let dy = laser.y2 - laser.y1
            let horizontal = abs(dy) < 0.5
            let vertical = abs(dx) < 0.5
            guard horizontal || vertical else {
                throw LevelValidationError(message: "The bundled level files could not be loaded.")
            }
        }
        let doorIDs = Set(level.doors.map(\.id))
        for sw in level.switches {
            guard doorIDs.contains(sw.doorId) else {
                throw LevelValidationError(message: "The bundled level files could not be loaded.")
            }
        }
    }
}
