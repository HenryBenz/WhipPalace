import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var app: AppState
    @State private var revealedStars = 0

    private var run: RunResults? { app.results }

    var body: some View {
        ZStack {
            ScreenBackground(imageName: "bg_results")
            if let run {
                ScrollView {
                    VStack(spacing: LayoutMetrics.sectionSpacing) {
                        titleBlock(run)
                        stars(run)
                        stats(run)
                        objectives(run)
                        buttons(run)
                    }
                    .padding(.horizontal, LayoutMetrics.horizontalMargin)
                    .padding(.top, 24)
                    .padding(.bottom, 28)
                }
            }
        }
        .onAppear {
            revealStars()
        }
    }

    private func titleBlock(_ run: RunResults) -> some View {
        VStack(spacing: 8) {
            if run.level.trial {
                Text("Royal Trial Complete")
                    .font(TypeScale.screenTitle)
                    .foregroundStyle(Palette.mainText)
            } else if Int(run.level.displayNumber) == 45 {
                Image("palace_trophy").resizable().scaledToFit().frame(height: 120)
                Text("Palace Restored")
                    .font(TypeScale.screenTitle)
                    .foregroundStyle(Palette.royalGold)
                Text("You have completed all 45 campaign chambers.")
                    .font(TypeScale.body)
                    .foregroundStyle(Palette.secondaryText)
                    .multilineTextAlignment(.center)
            } else if run.level.displayNumber == "R15" || (run.level.wing == .royal && app.royalNumber(run.level) == 15) {
                Image("completion_badge")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .colorMultiply(Palette.lavender)
                Text("Royal Chambers Complete")
                    .font(TypeScale.screenTitle)
                    .foregroundStyle(Palette.lavender)
            } else if [15, 30].contains(Int(run.level.displayNumber) ?? -1) {
                Image("completion_badge")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .colorMultiply(Palette.mint)
                Text("Wing Complete")
                    .font(TypeScale.panelTitle)
                    .foregroundStyle(Palette.brightLime)
            } else {
                Text("Chamber Complete")
                    .font(TypeScale.screenTitle)
                    .foregroundStyle(Palette.mainText)
            }
            if !run.level.trial && Int(run.level.displayNumber) != 45 {
                Text("Level \(run.level.displayNumber) — \(run.level.title)")
                    .font(TypeScale.body)
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func stars(_ run: RunResults) -> some View {
        let earned = [run.crystalObjective, run.noFallObjective, run.attachmentObjective]
        let best = app.progress.record(for: run.level).starCount
        return VStack(spacing: 8) {
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: earned[i] && i < revealedStars ? "star.fill" : "star")
                        .font(.system(size: 28))
                        .foregroundStyle(earned[i] && i < revealedStars ? Palette.royalGold : Palette.disabledText)
                }
            }
            if !run.isTrial {
                Text("Level Best: \(best) / 3 stars")
                    .font(TypeScale.secondary)
                    .foregroundStyle(Palette.secondaryText)
            }
        }
    }

    private func stats(_ run: RunResults) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Time: \(formatTime(run.time))")
            Text("Attachments: \(run.attachments)")
            Text("Falls: \(run.falls)")
            Text("Crystals: \(run.crystals) / 3")
        }
        .font(TypeScale.body)
        .foregroundStyle(Palette.mainText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LayoutMetrics.panelPadding)
        .background(RoundedRectangle(cornerRadius: LayoutMetrics.panelCorner).fill(Palette.panelFill.opacity(0.94)))
    }

    private func objectives(_ run: RunResults) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            objectiveRow("All crystals collected", run.crystalObjective)
            objectiveRow("No falls", run.noFallObjective)
            objectiveRow("Attachment limit met", run.attachmentObjective)
        }
        .padding(LayoutMetrics.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: LayoutMetrics.panelCorner).fill(Palette.panelFill.opacity(0.94)))
    }

    private func objectiveRow(_ title: String, _ ok: Bool) -> some View {
        HStack {
            Text(title)
                .font(TypeScale.body)
                .foregroundStyle(Palette.mainText)
            Spacer()
            Image(systemName: ok ? "checkmark" : "minus")
                .foregroundStyle(ok ? Palette.primaryLime : Palette.disabledText)
        }
    }

    @ViewBuilder
    private func buttons(_ run: RunResults) -> some View {
        if run.isTrial {
            MainButton(title: "View Royal Whip Pack") {
                app.audio.play(.uiTap)
                app.screen = .royalWhipPack
            }
            SecondaryButton(title: "Replay Trial") { replay(run) }
            SecondaryButton(title: "Main Menu") {
                app.audio.play(.uiTap)
                app.screen = .mainMenu
            }
        } else if Int(run.level.displayNumber) == 45 {
            MainButton(title: "Palace Map") { goMap(run.level.wing) }
            SecondaryButton(title: "Replay Level") { replay(run) }
            if app.purchases.isOwned {
                SecondaryButton(title: "Royal Chambers") {
                    app.audio.play(.uiTap)
                    app.selectedWing = .royal
                    app.progress.selectWing(.royal)
                    app.screen = .palaceMap
                }
            } else {
                SecondaryButton(title: "Explore Royal Whip Pack") {
                    app.audio.play(.uiTap)
                    app.screen = .royalWhipPack
                }
            }
        } else if run.level.wing == .royal && app.royalNumber(run.level) == 15 {
            MainButton(title: "Royal Map") { goMap(.royal) }
            SecondaryButton(title: "Replay Level") { replay(run) }
            SecondaryButton(title: "Main Menu") {
                app.audio.play(.uiTap)
                app.screen = .mainMenu
            }
        } else if [15, 30].contains(Int(run.level.displayNumber) ?? -1) {
            MainButton(title: "Enter Next Wing") {
                app.audio.play(.uiTap)
                let next: Wing = Int(run.level.displayNumber) == 15 ? .moving : .crown
                app.selectedWing = next
                app.progress.selectWing(next)
                app.screen = .palaceMap
            }
            SecondaryButton(title: "Replay Level") { replay(run) }
            SecondaryButton(title: "Palace Map") { goMap(run.level.wing) }
        } else {
            if let next = nextLevel(run.level), app.isLevelUnlocked(next) {
                MainButton(title: "Next Level") {
                    app.audio.play(.uiTap)
                    app.openLevelDetails(next)
                }
            }
            SecondaryButton(title: "Replay") { replay(run) }
            SecondaryButton(title: "Palace Map") { goMap(run.level.wing) }
        }
    }

    private func nextLevel(_ level: LevelDefinition) -> LevelDefinition? {
        if level.wing == .royal { return app.levels.nextRoyalLevel(after: level) }
        return app.levels.nextCampaignLevel(after: level)
    }

    private func replay(_ run: RunResults) {
        app.audio.play(.uiTap)
        app.selectedLevel = run.level
        app.startSelectedLevel()
    }

    private func goMap(_ wing: Wing) {
        app.audio.play(.uiTap)
        app.selectedWing = wing
        app.progress.selectWing(wing)
        app.screen = .palaceMap
    }

    private func revealStars() {
        guard let run else { return }
        let earned = [run.crystalObjective, run.noFallObjective, run.attachmentObjective]
        revealedStars = 0
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18 * Double(i + 1)) {
                revealedStars = i + 1
                if earned[i] { app.audio.play(.uiSelect, gain: 0.45) }
            }
        }
    }
}

struct PauseOverlay: View {
    @EnvironmentObject private var app: AppState
    @State private var confirmRestart = false
    @State private var confirmLeave = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
            VStack(spacing: LayoutMetrics.controlSpacing) {
                Text("Paused")
                    .font(TypeScale.screenTitle)
                    .foregroundStyle(Palette.mainText)
                MainButton(title: "Resume") {
                    app.audio.play(.uiTap)
                    app.isPaused = false
                    app.audio.resumeGameplayMusic()
                }
                SecondaryButton(title: "Restart Level") {
                    app.audio.play(.uiTap)
                    confirmRestart = true
                }
                SecondaryButton(title: "Settings") {
                    app.audio.play(.uiTap)
                    app.openSettings(from: .gameplay)
                }
                SecondaryButton(title: app.isTrialRun ? "Exit Trial" : "Exit to Map") {
                    app.audio.play(.uiTap)
                    confirmLeave = true
                }
            }
            .padding(LayoutMetrics.panelPadding)
            .background(RoundedRectangle(cornerRadius: LayoutMetrics.panelCorner).fill(Palette.panelFill))
            .padding(.horizontal, LayoutMetrics.horizontalMargin)

            if confirmRestart {
                ConfirmationDialogPanel(
                    title: "Restart Level?",
                    message: "Your current run will be discarded.",
                    cancelTitle: "Cancel",
                    confirmTitle: "Restart",
                    destructive: true,
                    cancel: { confirmRestart = false },
                    confirm: {
                        confirmRestart = false
                        NotificationCenter.default.post(name: .whipPalaceRestartLevel, object: nil)
                        app.isPaused = false
                        app.audio.resumeGameplayMusic()
                    }
                )
            }
            if confirmLeave {
                ConfirmationDialogPanel(
                    title: "Leave Level?",
                    message: "Your current run will not be saved.",
                    cancelTitle: "Stay",
                    confirmTitle: "Leave",
                    destructive: true,
                    cancel: { confirmLeave = false },
                    confirm: {
                        confirmLeave = false
                        app.exitGameplayToMap()
                    }
                )
            }
        }
    }
}

extension Notification.Name {
    static let whipPalaceRestartLevel = Notification.Name("whipPalaceRestartLevel")
    static let whipPalaceCancelTouch = Notification.Name("whipPalaceCancelTouch")
}
