import SwiftUI

struct PalaceMapView: View {
    @EnvironmentObject private var app: AppState

    private var levels: [LevelDefinition] {
        app.levels.levels(for: app.selectedWing)
    }

    var body: some View {
        ZStack {
            ScreenBackground(imageName: app.selectedWing.backgroundName)
            VStack(spacing: 12) {
                topBar
                wingSelector
                if let message = wingLockMessage {
                    Text(message)
                        .font(TypeScale.secondary)
                        .foregroundStyle(Palette.secondaryText)
                        .padding(.horizontal, LayoutMetrics.horizontalMargin)
                }
                ScrollView {
                    mapGrid
                        .padding(.horizontal, LayoutMetrics.horizontalMargin)
                        .padding(.bottom, 24)
                }
            }
        }
        .sheet(isPresented: $app.showLevelDetails) {
            if let level = app.selectedLevel {
                LevelDetailsSheet(level: level)
                    .environmentObject(app)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            app.audio.playMenuMusic()
        }
    }

    private var topBar: some View {
            HStack {
                BackButton {
                    app.audio.play(.uiTap)
                    app.screen = .mainMenu
                }
                Text("Palace Map")
                    .font(TypeScale.screenTitle)
                    .foregroundStyle(Palette.mainText)
                Spacer()
                if app.progress.progress.completedCampaignCount >= 45 {
                    Image("palace_trophy")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                }
                Text("\(app.progress.progress.campaignStars) / 135")
                    .font(TypeScale.hud)
                    .foregroundStyle(Palette.primaryLime)
            }
        .padding(.horizontal, LayoutMetrics.horizontalMargin)
    }

    private var wingLockMessage: String? {
        switch app.selectedWing {
        case .moving where !app.isWingUnlocked(.moving):
            return "Complete Level 15 to enter Moving Chambers."
        case .crown where !app.isWingUnlocked(.crown):
            return "Complete Level 30 to enter Crown Heights."
        default:
            return app.mapMessage
        }
    }

    private var wingSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Wing.allCases) { wing in
                    wingChip(wing)
                }
            }
            .padding(.horizontal, LayoutMetrics.horizontalMargin)
        }
    }

    private func wingChip(_ wing: Wing) -> some View {
        let selected = app.selectedWing == wing
        let completed = isWingCompleted(wing)
        return Button {
            tapWing(wing)
        } label: {
            HStack(spacing: 6) {
                if completed {
                    Image("completion_badge")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .colorMultiply(wing == .royal ? Palette.lavender : Palette.mint)
                }
                Text(wing.displayName)
                    .font(TypeScale.secondary)
                    .foregroundStyle(selected ? Palette.mainBackground : Palette.mainText)
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(
                Capsule().fill(selected ? (wing == .royal ? Palette.lavender : Palette.primaryLime) : Palette.panelFill)
            )
        }
        .frame(minHeight: LayoutMetrics.minTouch)
    }

    private func tapWing(_ wing: Wing) {
        if wing == .royal && !app.purchases.isOwned {
            app.audio.play(.uiTap)
            app.screen = .royalWhipPack
            return
        }
        if wing != .royal && !app.isWingUnlocked(wing) {
            app.audio.play(.uiBlocked)
            app.selectedWing = wing
            return
        }
        app.audio.play(.uiSelect)
        app.selectedWing = wing
        app.progress.selectWing(wing)
        app.mapMessage = nil
    }

    private func isWingCompleted(_ wing: Wing) -> Bool {
        let group = app.levels.levels(for: wing)
        guard !group.isEmpty else { return false }
        return group.allSatisfy { app.progress.record(for: $0).completed }
    }

    private var mapGrid: some View {
        let rows = stride(from: 0, to: levels.count, by: 3).map { Array(levels[$0..<min($0 + 3, levels.count)]) }
        return VStack(spacing: 28) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 18) {
                    ForEach(row) { level in
                        levelNode(level)
                    }
                }
            }
        }
        .padding(.top, 12)
        .background(alignment: .center) {
            Rectangle()
                .fill(Palette.primaryLime.opacity(0.18))
                .frame(width: 2)
                .padding(.vertical, 20)
        }
    }

    private func levelNode(_ level: LevelDefinition) -> some View {
        let unlocked = app.isLevelUnlocked(level)
        let record = app.progress.record(for: level)
        let asset = !unlocked ? "level_node_locked" : (record.completed ? "level_node_complete" : "level_node_available")
        return Button {
            if unlocked {
                app.audio.play(.uiTap)
                app.selectedLevel = level
                app.showLevelDetails = true
            } else {
                app.audio.play(.uiBlocked)
                if let n = Int(level.displayNumber) {
                    app.mapMessage = "Complete Level \(n - 1) first."
                } else if let n = app.royalNumber(level) {
                    app.mapMessage = "Complete Level R\(n - 1) first."
                }
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                    if unlocked {
                        Text(level.displayNumber)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Palette.mainText)
                    } else {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(Palette.disabledText)
                        Text(level.displayNumber)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.disabledText)
                            .offset(y: 18)
                    }
                }
                if record.completed {
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < record.starCount ? "star.fill" : "star")
                                .font(.system(size: 9))
                                .foregroundStyle(i < record.starCount ? Palette.royalGold : Palette.disabledText)
                        }
                    }
                } else {
                    Color.clear.frame(height: 12)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct LevelDetailsSheet: View {
    @EnvironmentObject private var app: AppState
    var level: LevelDefinition

    var body: some View {
        ZStack {
            Palette.secondaryBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: LayoutMetrics.controlSpacing) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(level.trial ? "Royal Chambers" : level.wing.displayName)
                            .font(TypeScale.secondary)
                            .foregroundStyle(level.wing == .royal || level.trial ? Palette.lavender : Palette.mint)
                        Text(level.trial ? "Royal Reach" : "Level \(level.displayNumber) — \(level.title)")
                            .font(TypeScale.panelTitle)
                            .foregroundStyle(Palette.mainText)
                    }
                    Spacer()
                    Button {
                        app.showLevelDetails = false
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Palette.secondaryText)
                            .frame(width: LayoutMetrics.minTouch, height: LayoutMetrics.minTouch)
                    }
                    .accessibilityLabel("Close")
                }
                if level.trial {
                    Text("Free Trial")
                        .font(TypeScale.hud)
                        .foregroundStyle(Palette.lavender)
                    Text("Try the adjustable Royal Whip in one practice chamber.")
                        .font(TypeScale.body)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                stats
                objectives
                if level.usesRoyalWhip {
                    Text("Royal Whip: drag vertically while attached to change rope length.")
                        .font(TypeScale.secondary)
                        .foregroundStyle(Palette.lavender)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                MainButton(title: level.trial ? "Start Trial" : "Start Level") {
                    app.audio.play(.uiTap)
                    app.selectedLevel = level
                    app.startSelectedLevel()
                }
            }
            .padding(LayoutMetrics.panelPadding)
        }
    }

    private var stats: some View {
        let record = app.progress.record(for: level)
        return VStack(alignment: .leading, spacing: 6) {
            starsRow(record.starCount)
            Text("Best Time: \(record.bestTime.map(formatTime) ?? "—")")
                .font(TypeScale.secondary)
                .foregroundStyle(Palette.secondaryText)
            Text("Best Attachments: \(record.bestAttachmentCount.map(String.init) ?? "—")")
                .font(TypeScale.secondary)
                .foregroundStyle(Palette.secondaryText)
        }
    }

    private func starsRow(_ count: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < count ? "star.fill" : "star")
                    .foregroundStyle(i < count ? Palette.royalGold : Palette.disabledText)
            }
        }
    }

    private var objectives: some View {
        let record = app.progress.record(for: level)
        return VStack(alignment: .leading, spacing: 8) {
            objective("Collect all 3 crystals", record.crystalObjectiveEarned)
            objective("Finish without a fall", record.noFallObjectiveEarned)
            objective("Use \(level.attachmentLimit) attachments or fewer", record.attachmentObjectiveEarned)
        }
    }

    private func objective(_ text: String, _ earned: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: earned ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(earned ? Palette.primaryLime : Palette.primaryLime.opacity(0.7))
            Text(text)
                .font(TypeScale.body)
                .foregroundStyle(Palette.mainText)
        }
    }
}
