import Foundation
import Combine
import UIKit

@MainActor
final class ProgressStore: ObservableObject {
    @Published private(set) var progress: GameProgress

    private let defaults: UserDefaults
    private let key = "whipPalace.progress"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key) {
            do {
                progress = try JSONDecoder().decode(GameProgress.self, from: data)
            } catch {
                progress = .empty
            }
        } else {
            progress = .empty
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(progress)
            defaults.set(data, forKey: key)
        } catch {
            // Keep running with in-memory progress.
        }
    }

    func record(for level: LevelDefinition) -> LevelRecord {
        progress.record(for: level)
    }

    func selectAppearance(_ appearance: BallAppearance) {
        progress.selectedAppearance = appearance
        save()
    }

    func selectWing(_ wing: Wing) {
        progress.lastSelectedWing = wing
        save()
    }

    func markTutorialFlag(_ update: (inout TutorialFlags) -> Void) {
        update(&progress.tutorialFlags)
        save()
    }

    func applyResults(_ results: RunResults) {
        var record = progress.record(for: results.level)
        record.completed = true
        if results.crystalObjective { record.crystalObjectiveEarned = true }
        if results.noFallObjective { record.noFallObjectiveEarned = true }
        if results.attachmentObjective { record.attachmentObjectiveEarned = true }
        if let best = record.bestTime {
            record.bestTime = min(best, results.time)
        } else {
            record.bestTime = results.time
        }
        if let best = record.bestAttachmentCount {
            record.bestAttachmentCount = min(best, results.attachments)
        } else {
            record.bestAttachmentCount = results.attachments
        }

        if results.level.trial {
            progress.trial = record
        } else if results.level.wing == .royal {
            progress.royal[results.level.id] = record
        } else {
            progress.campaign[results.level.id] = record
        }
        save()
    }

    func resetProgress() {
        let appearance = BallAppearance.limeSpark
        progress = GameProgress(
            schemaVersion: GameProgress.currentSchema,
            campaign: [:],
            royal: [:],
            trial: LevelRecord(),
            selectedAppearance: appearance,
            lastSelectedWing: .neon,
            tutorialFlags: TutorialFlags()
        )
        save()
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet { save() }
    }

    private let defaults: UserDefaults
    private let key = "whipPalace.settings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            var initial = AppSettings.defaultSettings
            initial.reducedEffects = UIAccessibility.isReduceMotionEnabled
            settings = initial
            persist(initial)
        }
    }

    private func save() {
        persist(settings)
    }

    private func persist(_ value: AppSettings) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}
