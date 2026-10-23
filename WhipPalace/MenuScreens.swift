import SwiftUI

struct LaunchView: View {
    @EnvironmentObject private var app: AppState
    @State private var pulse = false

    var body: some View {
        ZStack {
            ScreenBackground(imageName: "bg_splash", decorations: false)
            VStack(spacing: 28) {
                Spacer()
                LogoView(height: 150)
                    .padding(.top, 40)
                LaunchSpinner()
                    .opacity(0.9)
                Spacer()
                Text("Preparing the palace…")
                    .font(TypeScale.secondary)
                    .foregroundStyle(Palette.secondaryText)
                    .padding(.bottom, 36)
            }
            .padding(.horizontal, LayoutMetrics.horizontalMargin)
        }
        .onAppear { app.bootstrap() }
    }
}

struct LaunchSpinner: View {
    @State private var rot = false

    var body: some View {
        Circle()
            .trim(from: 0.12, to: 0.88)
            .stroke(Palette.primaryLime, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: 28, height: 28)
            .rotationEffect(.degrees(rot ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    rot = true
                }
            }
    }
}

struct LoadErrorView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ZStack {
            ScreenBackground(imageName: "bg_splash", decorations: false)
            Panel {
                Text("Unable to Load Levels")
                    .font(TypeScale.panelTitle)
                    .foregroundStyle(Palette.mainText)
                Text("The bundled level files could not be loaded.")
                    .font(TypeScale.body)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                MainButton(title: "Retry") {
                    app.audio.play(.uiTap)
                    app.retryLoad()
                }
            }
            .padding(.horizontal, LayoutMetrics.horizontalMargin)
        }
    }
}

struct MainMenuView: View {
    @EnvironmentObject private var app: AppState
    @State private var logoShift: CGFloat = 0
    @State private var crestGlow = 0.15

    var body: some View {
        ZStack {
            ScreenBackground(imageName: "bg_main_menu")
            Image("palace_crest")
                .resizable()
                .scaledToFit()
                .frame(width: 280)
                .opacity(app.settings.settings.reducedEffects ? 0.15 : crestGlow)
                .allowsHitTesting(false)
            VStack(spacing: LayoutMetrics.sectionSpacing) {
                LogoView(height: 118)
                    .offset(y: app.settings.settings.reducedEffects ? 0 : logoShift)
                    .padding(.top, 12)
                Spacer(minLength: 8)
                menuButtons
                campaignSummary
                utilityRow
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, LayoutMetrics.horizontalMargin)
        }
        .onAppear {
            app.audio.playMenuMusic()
            startMotion()
        }
        .onChange(of: app.settings.settings.reducedEffects) { _, reduced in
            if reduced {
                logoShift = 0
                crestGlow = 0.15
            } else {
                startMotion()
            }
        }
    }

    private var primaryTitle: String {
        if app.progress.progress.completedCampaignCount == 0 { return "Enter Palace" }
        if app.firstIncompleteCampaign == nil { return "Replay Palace" }
        return "Continue"
    }

    private var packTitle: String {
        app.purchases.isOwned ? "Royal Chambers" : "Royal Whip Pack"
    }

    private var menuButtons: some View {
        VStack(spacing: LayoutMetrics.controlSpacing) {
            MainButton(title: primaryTitle) {
                app.audio.play(.uiTap)
                app.openContinue()
            }
            MainButton(title: "Palace Map", fill: Palette.mint, textColor: Palette.mainBackground) {
                app.audio.play(.uiTap)
                app.openPalaceMap()
            }
            MainButton(title: "Ball Appearance") {
                app.audio.play(.uiTap)
                app.screen = .ballAppearance
            }
            MainButton(title: packTitle, fill: Palette.lavender, textColor: Palette.mainBackground) {
                app.audio.play(.uiTap)
                if app.purchases.isOwned {
                    app.selectedWing = .royal
                    app.progress.selectWing(.royal)
                    app.screen = .palaceMap
                } else {
                    app.screen = .royalWhipPack
                }
            }
        }
    }

    private var campaignSummary: some View {
        HStack(spacing: 10) {
            if app.progress.progress.completedCampaignCount >= 45 {
                Image("palace_trophy")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 36)
            }
            Text("Campaign Stars: \(app.progress.progress.campaignStars) / 135")
                .font(TypeScale.secondary)
                .foregroundStyle(Palette.secondaryText)
        }
    }

    private var utilityRow: some View {
        HStack(spacing: 16) {
            utility("How to Play", symbol: "questionmark.circle") { app.screen = .howToPlay }
            utility("Settings", symbol: "gearshape") { app.openSettings(from: .mainMenu) }
            utility("About", symbol: "info.circle") { app.screen = .about }
        }
    }

    private func utility(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            app.audio.play(.uiTap)
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Palette.panelFill.opacity(0.92))
                            .overlay(Circle().stroke(Palette.mint.opacity(0.4), lineWidth: 1))
                            .shadow(color: Palette.mint.opacity(0.18), radius: 6, y: 2)
                    )
                Text(title)
                    .font(TypeScale.secondary)
            }
            .foregroundStyle(Palette.mint)
            .frame(maxWidth: .infinity)
            .frame(minHeight: LayoutMetrics.minTouch)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func startMotion() {
        guard !app.settings.settings.reducedEffects else { return }
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            logoShift = 4
        }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            crestGlow = 0.25
        }
    }
}
