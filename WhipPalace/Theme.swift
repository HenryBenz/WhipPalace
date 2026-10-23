import SwiftUI

enum Palette {
    static let mainBackground = Color(hex: 0x090D0B)
    static let secondaryBackground = Color(hex: 0x151C17)
    static let panelFill = Color(hex: 0x18221B)
    static let primaryLime = Color(hex: 0xB7FF00)
    static let brightLime = Color(hex: 0xDFFF70)
    static let mint = Color(hex: 0x88F0C0)
    static let lavender = Color(hex: 0xB39AF5)
    static let mainText = Color(hex: 0xF7FAF7)
    static let secondaryText = Color(hex: 0xAFB8B1)
    static let disabledText = Color(hex: 0x667269)
    static let danger = Color(hex: 0xFF6476)
    static let royalGold = Color(hex: 0xFFD064)

    static let limeSparkTint = Color(hex: 0xB7FF00)
    static let mintPulseTint = Color(hex: 0x88F0C0)
    static let violetArcTint = Color(hex: 0xB39AF5)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

enum TypeScale {
    static let screenTitle: Font = .system(size: 28, weight: .bold)
    static let panelTitle: Font = .system(size: 20, weight: .semibold)
    static let mainButton: Font = .system(size: 17, weight: .bold, design: .rounded)
    static let body: Font = .system(size: 16, weight: .regular)
    static let secondary: Font = .system(size: 14, weight: .regular)
    static let hud: Font = .system(size: 13, weight: .semibold)
}

enum LayoutMetrics {
    static let horizontalMargin: CGFloat = 20
    static let sectionSpacing: CGFloat = 20
    static let controlSpacing: CGFloat = 12
    static let minTouch: CGFloat = 44
    static let mainButtonHeight: CGFloat = 56
    static let secondaryButtonHeight: CGFloat = 48
    static let buttonCorner: CGFloat = 20
    static let panelCorner: CGFloat = 22
    static let panelPadding: CGFloat = 20
}

enum PurchaseConfig {
    static let royalWhipPackProductID = "com.whippalace.royalwhippack"
}

enum GameplayMetrics {
    static let logicalWidth: CGFloat = 390
    static let ballRadius: CGFloat = 14
    static let maxSpeed: CGFloat = 620
    static let gravity: CGFloat = 900
    static let airDrag: CGFloat = 0.06
    static let platformFriction: CGFloat = 0.35
    static let attachBoost: CGFloat = 70
    static let whipCatchFactor: CGFloat = 0
    static let minRope: CGFloat = 36
    static let maxRope: CGFloat = 260
    static let attachRange: CGFloat = 320
    static let minAttachDistance: CGFloat = 28
    static let aimAngleDegrees: CGFloat = 55
    static let attachDragPoints: CGFloat = 8
    static let recatchDragPoints: CGFloat = 4
    static let recatchWindow: CGFloat = 0.4
    static let royalDeadzonePoints: CGFloat = 36
    static let fingerAimRadius: CGFloat = 92
    static let reelRestLength: CGFloat = 96
    static let reelSpeed: CGFloat = 520
    static let attachCooldownTime: CGFloat = 0.22
    static let royalMinRope: CGFloat = 50
    static let royalMaxRope: CGFloat = 260
    static let royalUnitsPerPoint: CGFloat = 0.6
    static let royalMaxLengthChange: CGFloat = 100
    static let crystalRadius: CGFloat = 24
    static let portalRadius: CGFloat = 56
    static let fallMargin: CGFloat = 180
    static let horizontalBoundTolerance: CGFloat = 20
    static let simulationStep: CGFloat = 1.0 / 120.0
    static let maxSimulationSteps = 8
    static let cameraFollowFraction: CGFloat = 0.58
    static let cameraSmooth: CGFloat = 0.18
    static let fragileBreakTime: CGFloat = 1.6
    static let fragileWarningLead: CGFloat = 0.3
    static let fragileReformTime: CGFloat = 3.0
    static let laserWarnTime: CGFloat = 0.35
    static let doorOpenTime: CGFloat = 0.25
    static let musicCrossfade: CGFloat = 0.4
}
