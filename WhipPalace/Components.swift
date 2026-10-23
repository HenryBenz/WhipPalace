import SwiftUI

struct ScreenBackground: View {
    var imageName: String
    var decorations: Bool = true

    var body: some View {
        GeometryReader { geo in
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .overlay(alignment: .bottom) {
                    if decorations {
                        Image("palace_floor_trim")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width)
                            .opacity(0.55)
                            .allowsHitTesting(false)
                    }
                }
        }
        .ignoresSafeArea()
    }
}

struct LogoView: View {
    var height: CGFloat = 120

    var body: some View {
        Image("whip_palace_logo")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityLabel("Whip Palace")
    }
}

struct MainButton: View {
    var title: String
    var fill: Color = Palette.primaryLime
    var textColor: Color = Palette.mainBackground
    var height: CGFloat = LayoutMetrics.mainButtonHeight
    var disabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TypeScale.mainButton)
                .tracking(0.4)
                .foregroundStyle(disabled ? Palette.disabledText : textColor)
                .shadow(color: Color.black.opacity(disabled ? 0 : 0.22), radius: 0, y: 1)
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
        .buttonStyle(FilledPalaceButtonStyle(fill: fill, disabled: disabled))
        .disabled(disabled)
        .frame(minHeight: LayoutMetrics.minTouch)
    }
}

struct SecondaryButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TypeScale.mainButton)
                .tracking(0.3)
                .foregroundStyle(Palette.primaryLime)
                .frame(maxWidth: .infinity)
                .frame(height: LayoutMetrics.secondaryButtonHeight)
        }
        .buttonStyle(OutlinedPalaceButtonStyle())
        .frame(minHeight: LayoutMetrics.minTouch)
    }
}

private struct FilledPalaceButtonStyle: ButtonStyle {
    var fill: Color
    var disabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                PalaceButtonPlate(
                    fill: fill,
                    filled: true,
                    disabled: disabled,
                    pressed: configuration.isPressed
                )
            }
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct OutlinedPalaceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                PalaceButtonPlate(
                    fill: Palette.primaryLime,
                    filled: false,
                    disabled: false,
                    pressed: configuration.isPressed
                )
            }
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct PalaceButtonPlate: View {
    var fill: Color
    var filled: Bool
    var disabled: Bool
    var pressed: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: LayoutMetrics.buttonCorner, style: .continuous)
        let glow = disabled ? 0 : (pressed ? 0.16 : 0.42)
        ZStack {
            shape
                .fill(fill.opacity(glow))
                .blur(radius: 12)
                .offset(y: 5)

            if filled {
                shape.fill(
                    LinearGradient(
                        colors: disabled
                            ? [Palette.secondaryBackground, Palette.panelFill]
                            : [fill, fill.opacity(0.82), fill.opacity(0.68)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            } else {
                shape.fill(
                    LinearGradient(
                        colors: [
                            Palette.panelFill.opacity(0.96),
                            Palette.secondaryBackground.opacity(0.92)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            shape
                .stroke(
                    LinearGradient(
                        colors: disabled
                            ? [Color.white.opacity(0.06), Color.clear]
                            : [Color.white.opacity(filled ? 0.55 : 0.28), fill.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: 1.2
                )
                .padding(0.8)

            shape
                .stroke(disabled ? Palette.disabledText.opacity(0.35) : fill.opacity(filled ? 0.7 : 0.85), lineWidth: 1)

            if !disabled {
                Capsule()
                    .fill(Color.white.opacity(filled ? 0.28 : 0.1))
                    .frame(height: 7)
                    .padding(.horizontal, 22)
                    .offset(y: filled ? -17 : -13)
                    .blur(radius: 3)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if pressed {
                shape.fill(Color.black.opacity(0.12))
            }
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct Panel<Content: View>: View {
    var title: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.controlSpacing) {
            if let title {
                Text(title)
                    .font(TypeScale.panelTitle)
                    .foregroundStyle(Palette.mainText)
            }
            content()
        }
        .padding(LayoutMetrics.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LayoutMetrics.panelCorner, style: .continuous)
                .fill(Palette.panelFill.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: LayoutMetrics.panelCorner, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Palette.primaryLime.opacity(0.28), Palette.mint.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Palette.primaryLime.opacity(0.08), radius: 16, y: 6)
    }
}

struct BackButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.primaryLime)
                .frame(width: LayoutMetrics.minTouch, height: LayoutMetrics.minTouch)
                .background(
                    Circle()
                        .fill(Palette.panelFill.opacity(0.92))
                        .overlay(
                            Circle().stroke(Palette.primaryLime.opacity(0.45), lineWidth: 1)
                        )
                        .shadow(color: Palette.primaryLime.opacity(0.22), radius: 8, y: 2)
                )
                .contentShape(Circle())
        }
        .accessibilityLabel("Back")
        .buttonStyle(ScaleButtonStyle())
    }
}

struct TopBar: View {
    var title: String
    var trailing: AnyView? = nil
    var back: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            BackButton(action: back)
            Text(title)
                .font(TypeScale.screenTitle)
                .foregroundStyle(Palette.mainText)
                .lineLimit(1)
            Spacer()
            if let trailing {
                trailing
            }
        }
        .padding(.horizontal, LayoutMetrics.horizontalMargin)
    }
}

struct ConfirmationDialogPanel: View {
    var title: String
    var message: String
    var cancelTitle: String
    var confirmTitle: String
    var destructive: Bool = false
    var cancel: () -> Void
    var confirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            Panel {
                Text(title)
                    .font(TypeScale.panelTitle)
                    .foregroundStyle(Palette.mainText)
                Text(message)
                    .font(TypeScale.body)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: LayoutMetrics.controlSpacing) {
                    SecondaryButton(title: cancelTitle, action: cancel)
                    MainButton(
                        title: confirmTitle,
                        fill: destructive ? Palette.danger : Palette.primaryLime,
                        textColor: destructive ? Palette.mainText : Palette.mainBackground,
                        action: confirm
                    )
                }
            }
            .padding(.horizontal, LayoutMetrics.horizontalMargin)
        }
    }
}

func formatTime(_ value: Double) -> String {
    let minutes = Int(value) / 60
    let seconds = value.truncatingRemainder(dividingBy: 60)
    return String(format: "%02d:%04.1f", minutes, seconds)
}
