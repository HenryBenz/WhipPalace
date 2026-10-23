import SwiftUI
import SpriteKit

final class GameHUDModel: ObservableObject {
    @Published var wingName = ""
    @Published var levelNumber = ""
    @Published var crystals = 0
    @Published var time = 0.0
    @Published var attachments = 0
    @Published var attachmentLimit = 0
    @Published var ropeLength: Int? = nil
    @Published var prompt: String? = nil
    @Published var showJester = false
    @Published var crystalPulse = false
    @Published var statusMessage: String? = nil
}

struct GameView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var hud = GameHUDModel()
    @State private var scene: GameScene?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let scene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                } else {
                    Palette.mainBackground.ignoresSafeArea()
                }
                hudOverlay
                if app.isPaused {
                    PauseOverlay()
                }
            }
            .onAppear { makeScene(size: geo.size) }
            .onChange(of: geo.size) { _, size in
                if scene == nil { makeScene(size: size) }
            }
        }
        .statusBarHidden(true)
        .onChange(of: app.isPaused) { _, paused in
            scene?.simulationPaused = paused
            if paused {
                app.audio.pauseGameplayMusic()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                app.audio.handleBackground()
                if app.screen == .gameplay || (app.screen == .settings && app.settingsOrigin == .gameplay) {
                    scene?.cancelActiveTouch(detach: true)
                    app.isPaused = true
                    scene?.simulationPaused = true
                }
            } else if app.screen == .gameplay {
                app.audio.apply(settings: app.settings.settings)
                if !app.isPaused {
                    app.audio.playGameplayMusic(for: app.selectedLevel ?? app.levels.campaignLevels[0])
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .whipPalaceRestartLevel)) { _ in
            scene?.restart()
        }
    }

    private var hudOverlay: some View {
        ZStack(alignment: .top) {
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hud.wingName)
                            .font(TypeScale.hud)
                            .foregroundStyle(Palette.mint)
                        Text(hud.levelNumber)
                            .font(TypeScale.hud)
                            .foregroundStyle(Palette.mainText)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image("crystal_pickup")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .scaleEffect(hud.crystalPulse ? 1.2 : 1)
                        Text("\(hud.crystals) / 3")
                            .font(TypeScale.hud)
                            .foregroundStyle(Palette.mainText)
                    }
                    Spacer()
                    Color.clear.frame(width: LayoutMetrics.minTouch, height: LayoutMetrics.minTouch)
                }
                HStack {
                    Text(formatTime(hud.time))
                        .font(TypeScale.hud)
                        .foregroundStyle(Palette.secondaryText)
                    Spacer()
                    Text(attachmentText)
                        .font(TypeScale.hud)
                        .foregroundStyle(Palette.secondaryText)
                }
                if let rope = hud.ropeLength {
                    Text("Rope: \(rope)")
                        .font(TypeScale.hud)
                        .foregroundStyle(Palette.lavender)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
                if let prompt = hud.prompt {
                    HStack(alignment: .bottom, spacing: 8) {
                        if hud.showJester {
                            Image(jesterName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 92)
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                        }
                        Text(prompt)
                            .font(TypeScale.secondary)
                            .foregroundStyle(Palette.mainText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(12)
                            .frame(maxWidth: 300, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.panelFill.opacity(0.92)))
                    }
                }
                if let status = hud.statusMessage {
                    Text(status)
                        .font(TypeScale.hud)
                        .foregroundStyle(Palette.brightLime)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, LayoutMetrics.horizontalMargin)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                app.audio.play(.uiTap)
                app.isPaused = true
                scene?.simulationPaused = true
                app.audio.pauseGameplayMusic()
            } label: {
                Image(systemName: "pause.fill")
                    .foregroundStyle(Palette.primaryLime)
                    .frame(width: LayoutMetrics.minTouch, height: LayoutMetrics.minTouch)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Pause")
            .padding(.trailing, LayoutMetrics.horizontalMargin)
            .padding(.top, 8)
        }
        .safeAreaPadding(.top)
        .safeAreaPadding(.bottom)
    }

    private var attachmentText: String {
        if hud.attachments > hud.attachmentLimit {
            return "Attachments: \(hud.attachments) / \(hud.attachmentLimit)"
        }
        return "Attachments: \(hud.attachments)"
    }

    private var jesterName: String {
        app.selectedLevel?.trial == true ? "jester_royal_host" : "jester_tutorial"
    }

    private func makeScene(size: CGSize) {
        guard scene == nil, let level = app.selectedLevel, size.width > 10, size.height > 10 else { return }
        let logicalHeight = GameplayMetrics.logicalWidth * (size.height / max(size.width, 1))
        let game = GameScene(size: CGSize(width: GameplayMetrics.logicalWidth, height: logicalHeight))
        game.scaleMode = .fill
        game.configure(
            level: level,
            appearance: app.progress.progress.selectedAppearance,
            reducedEffects: app.settings.settings.reducedEffects,
            tutorialFlags: app.progress.progress.tutorialFlags,
            audio: app.audio,
            haptics: app.haptics,
            hapticsEnabled: app.settings.settings.hapticsEnabled,
            hud: hud
        ) { results in
            app.finishLevel(results)
        } onPromptFlag: { flags in
            app.progress.markTutorialFlag { $0 = flags }
        }
        scene = game
    }
}
