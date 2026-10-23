import Foundation
import CoreGraphics

final class GameSession {
    var time: Double = 0
    var attachments = 0
    var falls = 0
    var collected: Set<String> = []
    var openedDoors: Set<String> = []
    var activatedSwitches: Set<String> = []
    var checkpointReached = false
    var checkpointCollected: Set<String> = []
    var checkpointDoors: Set<String> = []
    var checkpointSwitches: Set<String> = []
    var spawnPos = CGPoint.zero
    var checkpointSpawn = CGPoint.zero

    func reset(spawn: CGPoint) {
        time = 0
        attachments = 0
        falls = 0
        collected.removeAll()
        openedDoors.removeAll()
        activatedSwitches.removeAll()
        checkpointReached = false
        checkpointCollected.removeAll()
        checkpointDoors.removeAll()
        checkpointSwitches.removeAll()
        spawnPos = spawn
        checkpointSpawn = spawn
    }

    func results(for level: LevelDefinition) -> RunResults {
        RunResults(
            level: level,
            time: time,
            attachments: attachments,
            falls: falls,
            crystals: collected.count,
            crystalObjective: collected.count == 3,
            noFallObjective: falls == 0,
            attachmentObjective: attachments <= level.attachmentLimit,
            isTrial: level.trial
        )
    }
}

struct TutorialController {
    var flags: TutorialFlags
    var step = 0
    var trialStep = 0
    var holdTime: CGFloat = 0
    var shownMechanic: String?

    mutating func reset() {
        step = 0
        trialStep = 0
        holdTime = 0
        shownMechanic = nil
    }

    mutating func prompt(for level: LevelDefinition, attached: Bool, attachments: Int, crystals: Int, ropeLength: CGFloat, attachLength: CGFloat) -> (String?, Bool) {
        if level.id == "N01" {
            if !attached {
                return ("Put your finger on a glowing ring.", true)
            }
            return ("Keep holding, then put your finger on the next ring.", false)
        }
        if level.id == "N02", crystals == 0 {
            return ("Collect all three crystals to earn a star.", false)
        }
        if level.id == "N03", attachments < 2 {
            return ("After releasing, drag again to catch the next anchor.", false)
        }
        if level.trial {
            if trialStep == 0 {
                return ("Attach as usual.", true)
            }
            if trialStep == 1 {
                return ("Move your finger upward to shorten the rope.", false)
            }
            if trialStep == 2 {
                return ("Move your finger downward to lengthen the rope.", false)
            }
        }
        return (shownMechanic, false)
    }

    mutating func noteAttach(level: LevelDefinition) {
        if level.id == "N01", step == 0 { step = 1 }
        if level.trial, trialStep == 0 { trialStep = 1 }
    }

    mutating func noteHold(_ dt: CGFloat, attached: Bool) {
        if attached { holdTime += dt } else { holdTime = 0 }
    }

    mutating func noteRelease(level: LevelDefinition, ropeLength: CGFloat, attachLength: CGFloat) {
        if level.id == "N01", step == 2 { step = 3 }
        if level.trial, trialStep == 2 { trialStep = 3 }
    }

    mutating func noteRoyalAdjust(attached: Bool, ropeLength: CGFloat, attachLength: CGFloat) {
        if trialStep == 1, attached, ropeLength < attachLength - 8 { trialStep = 2 }
    }

    mutating func revealMechanic(ifNeeded level: LevelDefinition) -> TutorialFlags? {
        if shownMechanic != nil { return nil }
        if level.anchors.contains(where: { $0.type == .moving }), !flags.shownMovingAnchor {
            flags.shownMovingAnchor = true
            shownMechanic = "Moving anchors carry your swing with them."
            return flags
        }
        if level.anchors.contains(where: { $0.type == .fragile }), !flags.shownFragileAnchor {
            flags.shownFragileAnchor = true
            shownMechanic = "Cracked anchors break if you hold too long."
            return flags
        }
        if level.anchors.contains(where: { $0.type == .rotating }), !flags.shownRotatingAnchor {
            flags.shownRotatingAnchor = true
            shownMechanic = "Watch the anchor's orbit before you attach."
            return flags
        }
        if !level.lasers.isEmpty, !flags.shownLaser {
            flags.shownLaser = true
            shownMechanic = "Cross when the laser switches off."
            return flags
        }
        if !level.switches.isEmpty, !flags.shownSwitch {
            flags.shownSwitch = true
            shownMechanic = "Touch the switch to open its energy door."
            return flags
        }
        return nil
    }
}
