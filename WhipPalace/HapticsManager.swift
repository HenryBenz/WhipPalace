import UIKit
import CoreHaptics

final class HapticsManager {
    private var lastTime: TimeInterval = 0
    private let throttle: TimeInterval = 0.12

    func attach(enabled: Bool) {
        fire(.light, enabled: enabled)
    }

    func crystal(enabled: Bool) {
        fire(.light, enabled: enabled)
    }

    func hazard(enabled: Bool) {
        fire(.medium, enabled: enabled)
    }

    private func fire(_ style: UIImpactFeedbackGenerator.FeedbackStyle, enabled: Bool) {
        guard enabled else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastTime >= throttle else { return }
        lastTime = now
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
