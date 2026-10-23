import SwiftUI

struct BallAppearanceView: View {
    @EnvironmentObject private var app: AppState
    @State private var pulse: CGFloat = 1

    var body: some View {
        ZStack {
            ScreenBackground(imageName: "bg_main_menu")
            VStack(spacing: LayoutMetrics.sectionSpacing) {
                TopBar(title: "Ball Appearance") {
                    app.audio.play(.uiTap)
                    app.screen = .mainMenu
                }
                preview
                VStack(spacing: LayoutMetrics.controlSpacing) {
                    ForEach(BallAppearance.allCases) { item in
                        appearanceCard(item)
                    }
                }
                .padding(.horizontal, LayoutMetrics.horizontalMargin)
                Spacer()
            }
        }
        .onAppear {
            app.audio.playMenuMusic()
            if !app.settings.settings.reducedEffects {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    pulse = 1.08
                }
            }
        }
    }

    private var preview: some View {
        ZStack {
            Circle()
                .fill(Color(hex: app.progress.progress.selectedAppearance.tint).opacity(0.25))
                .frame(width: 160, height: 160)
                .scaleEffect(pulse)
            Image("energy_ball")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .colorMultiply(Color(hex: app.progress.progress.selectedAppearance.tint))
        }
        .padding(.top, 8)
    }

    private func appearanceCard(_ item: BallAppearance) -> some View {
        let stars = app.progress.progress.campaignStars
        let unlocked = stars >= item.requiredStars
        let selected = app.progress.progress.selectedAppearance == item
        return Button {
            if unlocked {
                app.progress.selectAppearance(item)
                app.audio.play(.uiSelect)
            } else {
                app.audio.play(.uiBlocked)
            }
        } label: {
            HStack(spacing: 14) {
                Image("energy_ball")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .colorMultiply(Color(hex: item.tint))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .font(TypeScale.body)
                        .foregroundStyle(Palette.mainText)
                    Text(stateLabel(item, unlocked: unlocked, selected: selected))
                        .font(TypeScale.secondary)
                        .foregroundStyle(unlocked ? Palette.secondaryText : Palette.royalGold)
                        .opacity(unlocked ? 1 : 1)
                }
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: LayoutMetrics.panelCorner, style: .continuous)
                    .fill(Palette.panelFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: LayoutMetrics.panelCorner, style: .continuous)
                            .stroke(selected ? Palette.primaryLime : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .frame(minHeight: LayoutMetrics.minTouch)
    }

    private func stateLabel(_ item: BallAppearance, unlocked: Bool, selected: Bool) -> String {
        if selected { return "Selected" }
        if unlocked { return "Select" }
        if item == .mintPulse { return "Requires 15 campaign stars" }
        return "Requires 45 campaign stars"
    }
}

struct RoyalWhipPackView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ZStack {
            ScreenBackground(imageName: "bg_royal_chambers")
            VStack(spacing: 12) {
                TopBar(title: "Royal Whip Pack") {
                    app.audio.play(.uiTap)
                    app.screen = .mainMenu
                }
                ScrollView {
                    VStack(spacing: LayoutMetrics.sectionSpacing) {
                        Image("royal_whip_emblem")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 96, height: 96)
                        Text("A new way to swing.")
                            .font(TypeScale.panelTitle)
                            .foregroundStyle(Palette.lavender)
                        HStack(alignment: .top, spacing: 12) {
                            Image("jester_royal_host")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 180)
                            Text("Adjust your rope length while attached and explore 15 chambers designed for the Royal Whip.")
                                .font(TypeScale.body)
                                .foregroundStyle(Palette.mainText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        featureList
                        Text("The Royal Whip is used in the trial and Royal Chambers. Campaign levels keep their original whip.")
                            .font(TypeScale.secondary)
                            .foregroundStyle(Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        if let banner = app.purchases.bannerMessage {
                            Text(banner)
                                .font(TypeScale.body)
                                .foregroundStyle(Palette.brightLime)
                        }
                        if let err = app.purchases.errorMessage, app.purchases.status == .unavailable {
                            Text(err)
                                .font(TypeScale.secondary)
                                .foregroundStyle(Palette.danger)
                        }
                        if app.purchases.status == .pending {
                            Text("Purchase pending approval.")
                                .font(TypeScale.secondary)
                                .foregroundStyle(Palette.royalGold)
                        }
                        controls
                    }
                    .padding(.horizontal, LayoutMetrics.horizontalMargin)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear { app.audio.playMenuMusic() }
        .sheet(isPresented: $app.showLevelDetails) {
            if let level = app.selectedLevel {
                LevelDetailsSheet(level: level)
                    .environmentObject(app)
            }
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 8) {
            feature("15 additional chambers")
            feature("Adjustable rope length")
            feature("New rope-control puzzles")
            feature("One-time purchase")
        }
        .padding(LayoutMetrics.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: LayoutMetrics.panelCorner).fill(Palette.panelFill.opacity(0.92)))
    }

    private func feature(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .foregroundStyle(Palette.lavender)
            Text(text)
                .font(TypeScale.body)
                .foregroundStyle(Palette.mainText)
        }
    }

    @ViewBuilder
    private var controls: some View {
        if app.purchases.isOwned {
            Text("Owned")
                .font(TypeScale.hud)
                .foregroundStyle(Palette.royalGold)
            MainButton(title: "Enter Royal Chambers", fill: Palette.lavender) {
                app.audio.play(.uiTap)
                app.selectedWing = .royal
                app.progress.selectWing(.royal)
                app.screen = .palaceMap
            }
            SecondaryButton(title: "Try Practice Chamber", action: openTrial)
            restoreButton
        } else {
            purchaseButton
            SecondaryButton(title: "Try Free Chamber", action: openTrial)
            restoreButton
            if app.purchases.status == .unavailable {
                MainButton(title: "Retry") {
                    Task { await app.purchases.loadProduct() }
                }
            }
        }
    }

    private var purchaseButton: some View {
        let loading = app.purchases.status == .loadingPrice
        let busy = app.purchases.status == .purchasing || app.purchases.status == .restoring
        let title: String
        if loading {
            title = "Loading Price…"
        } else if let price = app.purchases.localizedPriceText {
            title = "Buy Royal Whip Pack — \(price)"
        } else {
            title = "Buy Royal Whip Pack"
        }
        return ZStack {
            MainButton(title: title, fill: Palette.lavender, disabled: loading || busy || app.purchases.product == nil) {
                app.audio.play(.uiTap)
                Task { await app.purchases.purchase() }
            }
            if busy {
                ProgressView().tint(Palette.mainBackground)
            }
        }
    }

    private var restoreButton: some View {
        let busy = app.purchases.status == .purchasing || app.purchases.status == .restoring
        return SecondaryButton(title: "Restore Purchases") {
            guard !busy else { return }
            app.audio.play(.uiTap)
            Task { await app.purchases.restore() }
        }
        .disabled(busy)
    }

    private func openTrial() {
        app.audio.play(.uiTap)
        if let trial = app.levels.trialLevel {
            app.selectedLevel = trial
            app.showLevelDetails = true
        }
    }
}
