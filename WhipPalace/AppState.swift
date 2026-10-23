import Foundation
import SwiftUI
import Combine

enum AppScreen: Equatable {
    case launch
    case loadError
    case mainMenu
    case palaceMap
    case gameplay
    case results
    case ballAppearance
    case royalWhipPack
    case howToPlay
    case settings
    case about
}

@MainActor
final class AppState: ObservableObject {
    @Published var screen: AppScreen = .launch
    @Published var selectedWing: Wing = .neon
    @Published var selectedLevel: LevelDefinition?
    @Published var showLevelDetails = false
    @Published var isPaused = false
    @Published var results: RunResults?
    @Published var settingsOrigin: AppScreen = .mainMenu
    @Published var isTrialRun = false
    @Published var progressResetNotice = false
    @Published var mapMessage: String?

    let progress: ProgressStore
    let settings: SettingsStore
    let purchases: PurchaseManager
    let audio: AudioManager
    let levels = LevelRepository()
    let haptics = HapticsManager()
    private var cancellables = Set<AnyCancellable>()

    init() {
        progress = ProgressStore()
        settings = SettingsStore()
        purchases = PurchaseManager()
        audio = AudioManager()
        audio.apply(settings: settings.settings)
        progress.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        settings.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        purchases.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        purchases.start()
    }

    func bootstrap() {
        audio.loadReferences()
        audio.apply(settings: settings.settings)
        purchases.start()
        do {
            try levels.loadBundled()
            selectedWing = availableWing(progress.progress.lastSelectedWing)
            screen = .mainMenu
            audio.playMenuMusic()
            presentPackFromAppStoreIfNeeded()
        } catch {
            screen = .loadError
        }
    }

    func presentPackFromAppStoreIfNeeded() {
        guard purchases.pendingPackPresentation else { return }
        switch screen {
        case .launch, .loadError, .gameplay:
            return
        case .settings:
            if settingsOrigin == .gameplay { return }
            fallthrough
        default:
            if screen != .royalWhipPack {
                screen = .royalWhipPack
                audio.playMenuMusic()
            }
            purchases.acknowledgePackPresentation()
        }
    }

    func retryLoad() {
        bootstrap()
    }

    func availableWing(_ wing: Wing) -> Wing {
        if wing == .royal {
            return purchases.isOwned ? .royal : .neon
        }
        if isWingUnlocked(wing) { return wing }
        return .neon
    }

    func isWingUnlocked(_ wing: Wing) -> Bool {
        switch wing {
        case .neon: return true
        case .moving: return isCampaignCompleted(15)
        case .crown: return isCampaignCompleted(30)
        case .royal: return purchases.isOwned
        }
    }

    func isCampaignCompleted(_ number: Int) -> Bool {
        guard let level = levels.campaignLevel(number: number) else { return false }
        return progress.progress.campaign[level.id]?.completed == true
    }

    func isLevelUnlocked(_ level: LevelDefinition) -> Bool {
        if level.trial { return true }
        if level.wing == .royal {
            guard purchases.isOwned else { return false }
            guard let n = royalNumber(level), n > 1 else { return true }
            guard let previous = levels.royalLevels.first(where: { royalNumber($0) == n - 1 }) else { return false }
            return progress.progress.royal[previous.id]?.completed == true
        }
        guard let n = Int(level.displayNumber) else { return false }
        if n <= 1 { return true }
        guard let previous = levels.campaignLevel(number: n - 1) else { return false }
        return progress.progress.campaign[previous.id]?.completed == true
    }

    func royalNumber(_ level: LevelDefinition) -> Int? {
        if let value = Int(level.displayNumber) { return value }
        return Int(level.displayNumber.replacingOccurrences(of: "R", with: ""))
    }

    var firstIncompleteCampaign: LevelDefinition? {
        levels.campaignLevels.first { progress.progress.campaign[$0.id]?.completed != true }
    }

    func openContinue() {
        if progress.progress.completedCampaignCount == 0 {
            openLevelDetails(levels.campaignLevel(number: 1))
            return
        }
        if let next = firstIncompleteCampaign {
            openLevelDetails(next)
        } else {
            selectedWing = .crown
            progress.selectWing(.crown)
            screen = .palaceMap
        }
    }

    func openPalaceMap() {
        selectedWing = availableWing(progress.progress.lastSelectedWing)
        screen = .palaceMap
    }

    func openLevelDetails(_ level: LevelDefinition?) {
        guard let level else { return }
        selectedLevel = level
        selectedWing = level.wing
        if !level.trial {
            progress.selectWing(level.wing)
            screen = .palaceMap
        }
        showLevelDetails = true
    }

    func startSelectedLevel() {
        guard let level = selectedLevel, isLevelUnlocked(level) || level.trial else { return }
        showLevelDetails = false
        isTrialRun = level.trial
        isPaused = false
        results = nil
        screen = .gameplay
        audio.playGameplayMusic(for: level)
    }

    func finishLevel(_ run: RunResults) {
        progress.applyResults(run)
        results = run
        isPaused = false
        screen = .results
        audio.stopMusic()
        audio.play(.levelComplete)
        if run.isTrial { isTrialRun = false }
    }

    func exitGameplayToMap() {
        let wing = selectedLevel?.wing ?? selectedWing
        destroyRun()
        if isTrialRun {
            screen = .royalWhipPack
            audio.playMenuMusic()
            isTrialRun = false
            return
        }
        selectedWing = availableWing(wing)
        screen = .palaceMap
        audio.playMenuMusic()
    }

    func destroyRun() {
        isPaused = false
        selectedLevel = selectedLevel
    }

    func openSettings(from origin: AppScreen) {
        settingsOrigin = origin
        screen = .settings
    }

    func closeSettings() {
        progressResetNotice = false
        if settingsOrigin == .gameplay || settingsOrigin == .settings {
            screen = .gameplay
            isPaused = true
        } else {
            screen = settingsOrigin
        }
    }

    func handleResetProgress() {
        progress.resetProgress()
        selectedWing = .neon
        if settingsOrigin == .gameplay {
            isPaused = false
            selectedLevel = nil
            progressResetNotice = false
            screen = .mainMenu
            audio.playMenuMusic()
        } else {
            progressResetNotice = true
            screen = .settings
        }
    }

    func becomeInactiveDuringGameplay() {
        guard screen == .gameplay || (screen == .settings && settingsOrigin == .gameplay) else { return }
        isPaused = true
        audio.pauseGameplayMusic()
    }
}
