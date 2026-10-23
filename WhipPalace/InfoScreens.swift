import SwiftUI

struct HowToPlayView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ZStack {
            ScreenBackground(imageName: "bg_main_menu")
            VStack(spacing: 12) {
                TopBar(title: "How to Play") {
                    app.audio.play(.uiTap)
                    app.screen = .mainMenu
                }
                ScrollView {
                    VStack(spacing: LayoutMetrics.controlSpacing) {
                        HowToCard(title: "Attach", text: "Put your finger on a glowing ring. The whip pulls you toward it.") {
                            AttachDiagram()
                        }
                        HowToCard(title: "Swing", text: "Keep holding. Move your finger onto the next ring to climb.") {
                            SwingDiagram()
                        }
                        HowToCard(title: "Release", text: "Lift your finger to drop or fly to a platform.") {
                            ReleaseDiagram()
                        }
                        HowToCard(title: "Collect", text: "Collect all three crystals in each chamber.") {
                            CollectDiagram()
                        }
                        HowToCard(title: "Checkpoints", text: "A beacon saves your position inside the current run.") {
                            CheckpointDiagram()
                        }
                        HowToCard(title: "Earn Stars", text: "Collect all crystals, avoid falls, and stay within the attachment limit.") {
                            StarsDiagram()
                        }
                        HowToCard(title: "Royal Whip", text: "After you are attached, slide your finger farther up or down to change rope length.") {
                            RoyalDiagram()
                        }
                    }
                    .padding(.horizontal, LayoutMetrics.horizontalMargin)
                    .padding(.bottom, 12)
                }
                MainButton(title: "Practice Level 1") {
                    app.audio.play(.uiTap)
                    app.openLevelDetails(app.levels.campaignLevel(number: 1))
                }
                .padding(.horizontal, LayoutMetrics.horizontalMargin)
                .padding(.bottom, 8)
            }
        }
        .onAppear { app.audio.playMenuMusic() }
    }
}

private struct HowToCard<Diagram: View>: View {
    var title: String
    var text: String
    @ViewBuilder var diagram: () -> Diagram

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            diagram()
                .frame(height: 92)
                .frame(maxWidth: .infinity)
            Text(title)
                .font(TypeScale.panelTitle)
                .foregroundStyle(Palette.mainText)
            Text(text)
                .font(TypeScale.body)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(LayoutMetrics.panelPadding)
        .background(RoundedRectangle(cornerRadius: LayoutMetrics.panelCorner).fill(Palette.panelFill.opacity(0.94)))
    }
}

private struct AttachDiagram: View {
    var body: some View {
        ZStack {
            Circle().fill(Palette.primaryLime).frame(width: 18, height: 18).offset(x: -70, y: 16)
            Path { p in
                p.move(to: CGPoint(x: 40, y: 58))
                p.addLine(to: CGPoint(x: 140, y: 28))
            }
            .stroke(Palette.mint, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            Image("anchor_standard").resizable().scaledToFit().frame(width: 34, height: 34).offset(x: 70, y: -18)
        }
    }
}

private struct SwingDiagram: View {
    var body: some View {
        ZStack {
            Image("anchor_standard").resizable().scaledToFit().frame(width: 30, height: 30).offset(y: -28)
            Path { p in
                p.move(to: CGPoint(x: 110, y: 18))
                p.addLine(to: CGPoint(x: 70, y: 70))
            }
            .stroke(Palette.primaryLime, lineWidth: 3)
            Circle().fill(Palette.brightLime).frame(width: 16, height: 16).offset(x: -40, y: 24)
        }
    }
}

private struct ReleaseDiagram: View {
    var body: some View {
        HStack(spacing: 20) {
            Circle().fill(Palette.primaryLime).frame(width: 16, height: 16)
            Image(systemName: "arrow.right").foregroundStyle(Palette.mint)
            Circle().stroke(Palette.mint, lineWidth: 2).frame(width: 16, height: 16)
            Image("anchor_standard").resizable().scaledToFit().frame(width: 28, height: 28)
        }
    }
}

private struct CollectDiagram: View {
    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                Image("crystal_pickup").resizable().scaledToFit().frame(width: 28, height: 28)
            }
        }
    }
}

private struct CheckpointDiagram: View {
    var body: some View {
        Image("checkpoint_beacon").resizable().scaledToFit().frame(height: 80)
    }
}

private struct StarsDiagram: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in
                Image(systemName: "star.fill").foregroundStyle(Palette.royalGold).font(.system(size: 22))
            }
        }
    }
}

private struct RoyalDiagram: View {
    var body: some View {
        ZStack {
            Image("anchor_standard").resizable().scaledToFit().frame(width: 28, height: 28).offset(y: -28)
            Path { p in
                p.move(to: CGPoint(x: 110, y: 18))
                p.addLine(to: CGPoint(x: 110, y: 78))
            }
            .stroke(Palette.lavender, lineWidth: 3)
            Image(systemName: "arrow.up.arrow.down").foregroundStyle(Palette.lavender).offset(x: 36)
            Circle().fill(Palette.lavender).frame(width: 16, height: 16).offset(y: 32)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @State private var confirmReset = false

    private var musicEnabled: Binding<Bool> {
        Binding(get: { app.settings.settings.musicEnabled }, set: { app.settings.settings.musicEnabled = $0 })
    }
    private var musicVolume: Binding<Double> {
        Binding(get: { app.settings.settings.musicVolume }, set: { app.settings.settings.musicVolume = $0 })
    }
    private var effectsEnabled: Binding<Bool> {
        Binding(get: { app.settings.settings.effectsEnabled }, set: { app.settings.settings.effectsEnabled = $0 })
    }
    private var effectsVolume: Binding<Double> {
        Binding(get: { app.settings.settings.effectsVolume }, set: { app.settings.settings.effectsVolume = $0 })
    }
    private var hapticsEnabled: Binding<Bool> {
        Binding(get: { app.settings.settings.hapticsEnabled }, set: { app.settings.settings.hapticsEnabled = $0 })
    }
    private var reducedEffects: Binding<Bool> {
        Binding(get: { app.settings.settings.reducedEffects }, set: { app.settings.settings.reducedEffects = $0 })
    }

    var body: some View {
        ZStack {
            ScreenBackground(imageName: "bg_main_menu")
            VStack(spacing: 12) {
                TopBar(title: "Settings") {
                    app.audio.play(.uiTap)
                    app.closeSettings()
                }
                ScrollView {
                    VStack(spacing: LayoutMetrics.sectionSpacing) {
                        audioSection("Music", enabled: musicEnabled, volume: musicVolume)
                        audioSection("Sound Effects", enabled: effectsEnabled, volume: effectsVolume)
                        Panel(title: "Haptics") {
                            Toggle("Haptics", isOn: hapticsEnabled)
                                .tint(Palette.primaryLime)
                                .foregroundStyle(Palette.mainText)
                        }
                        Panel(title: "Reduced Effects") {
                            Toggle("Reduced Effects", isOn: reducedEffects)
                                .tint(Palette.primaryLime)
                                .foregroundStyle(Palette.mainText)
                            Text("Reduce decorative motion, particles, and screen effects.")
                                .font(TypeScale.secondary)
                                .foregroundStyle(Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        MainButton(title: "Reset Game Progress", fill: Palette.danger, textColor: Palette.mainText) {
                            app.audio.play(.uiTap)
                            confirmReset = true
                        }
                        if app.progressResetNotice {
                            Text("Progress Reset")
                                .font(TypeScale.body)
                                .foregroundStyle(Palette.brightLime)
                        }
                    }
                    .padding(.horizontal, LayoutMetrics.horizontalMargin)
                    .padding(.bottom, 24)
                }
            }
            if confirmReset {
                ConfirmationDialogPanel(
                    title: "Reset Game Progress?",
                    message: "Campaign progress, Royal level results, appearance unlocks, and tutorial history will be cleared. Your purchase and audio settings will remain.",
                    cancelTitle: "Cancel",
                    confirmTitle: "Reset Progress",
                    destructive: true,
                    cancel: { confirmReset = false },
                    confirm: {
                        confirmReset = false
                        app.handleResetProgress()
                    }
                )
            }
        }
        .onChange(of: app.settings.settings) { _, newValue in
            app.audio.apply(settings: newValue)
        }
    }

    private func audioSection(_ title: String, enabled: Binding<Bool>, volume: Binding<Double>) -> some View {
        Panel(title: title) {
            Toggle(title, isOn: enabled)
                .tint(Palette.primaryLime)
                .foregroundStyle(Palette.mainText)
            Slider(value: volume, in: 0...1)
                .tint(Palette.primaryLime)
        }
    }
}

struct AboutView: View {
    @EnvironmentObject private var app: AppState

    private var versionText: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(v) (\(b))"
    }

    var body: some View {
        ZStack {
            ScreenBackground(imageName: "bg_main_menu")
            VStack(spacing: 12) {
                TopBar(title: "About") {
                    app.audio.play(.uiTap)
                    app.screen = .mainMenu
                }
                ScrollView {
                    VStack(spacing: LayoutMetrics.sectionSpacing) {
                        LogoView(height: 110)
                        Text("Whip Palace")
                            .font(TypeScale.panelTitle)
                            .foregroundStyle(Palette.mainText)
                        Text(versionText)
                            .font(TypeScale.secondary)
                            .foregroundStyle(Palette.secondaryText)
                        aboutCard("Swing through a neon palace using an energy whip. Master your momentum, collect crystals, and restore every chamber.")
                        aboutCard("Whip Palace does not include accounts, advertising, analytics, or a custom backend. Game progress and settings are stored on this device. The app does not access your camera, photos, or microphone.")
                        aboutCard("Royal Whip Pack is an optional one-time purchase processed by Apple. Purchases can be restored from the Royal Whip Pack screen.")
                        MainButton(title: "Royal Whip Pack", fill: Palette.lavender) {
                            app.audio.play(.uiTap)
                            app.screen = .royalWhipPack
                        }
                    }
                    .padding(.horizontal, LayoutMetrics.horizontalMargin)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear { app.audio.playMenuMusic() }
    }

    private func aboutCard(_ text: String) -> some View {
        Text(text)
            .font(TypeScale.body)
            .foregroundStyle(Palette.mainText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(LayoutMetrics.panelPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: LayoutMetrics.panelCorner).fill(Palette.panelFill.opacity(0.94)))
    }
}
