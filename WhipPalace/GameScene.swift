import SpriteKit
import UIKit

final class GameScene: SKScene {
    private var level: LevelDefinition!
    private var appearance: BallAppearance = .limeSpark
    private var reducedEffects = false
    private weak var audio: AudioManager?
    private var haptics: HapticsManager?
    private var hapticsEnabled = true
    private weak var hud: GameHUDModel?
    private var onComplete: ((RunResults) -> Void)?
    private var onPromptFlag: ((TutorialFlags) -> Void)?

    var simulationPaused = false

    private let worldWidth = GameplayMetrics.logicalWidth
    private var visibleHeight: CGFloat { size.height }

    private var ballNode = SKSpriteNode()
    private var ballPos = CGPoint.zero
    private var ballVel = CGVector.zero
    private var ballRadius = GameplayMetrics.ballRadius
    private var inputEnabled = true
    private var completing = false

    private var attachedID: String?
    private var ropeLength: CGFloat = 0
    private var royalFingerStart: CGPoint?
    private var royalLengthAtAttach: CGFloat = 0
    private var lastAnchorWorld = CGPoint.zero
    private var lastAnchorVelocity = CGVector.zero

    private var activeTouch: UITouch?
    private var aimStartView = CGPoint.zero
    private var aimCurrentScene = CGPoint.zero
    private var attachedThisTouch = false
    private var candidateID: String?
    private var recatchTimer: CGFloat = 0
    private var attachCooldown: CGFloat = 0
    private var ignoreTouchUntilEnded = false
    private var reeling = false

    private var elapsed: CGFloat = 0
    private var runTime: Double = 0
    private var attachments = 0
    private var falls = 0
    private var collected: Set<String> = []
    private var openedDoors: Set<String> = []
    private var activatedSwitches: Set<String> = []
    private var checkpointReached = false
    private var checkpointCollected: Set<String> = []
    private var checkpointDoors: Set<String> = []
    private var checkpointSwitches: Set<String> = []
    private var spawnPos = CGPoint.zero
    private var checkpointSpawn = CGPoint.zero

    private var accumulator: CGFloat = 0
    private var cameraY: CGFloat = 0
    private var cameraTargetY: CGFloat = 0

    private var platformNodes: [String: SKShapeNode] = [:]
    private var anchorNodes: [String: SKSpriteNode] = [:]
    private var crystalNodes: [String: SKSpriteNode] = [:]
    private var laserBeams: [String: SKShapeNode] = [:]
    private var doorBarriers: [String: SKShapeNode] = [:]
    private var ropeGlow = SKShapeNode()
    private var ropeCore = SKShapeNode()
    private var ropePulse = SKShapeNode(circleOfRadius: 3.5)
    private var aimLine = SKShapeNode()
    private var portalNode = SKSpriteNode()
    private var portalRing = SKShapeNode(circleOfRadius: 34)

    private var fragileTimers: [String: CGFloat] = [:]
    private var fragileBroken: [String: CGFloat] = [:]
    private var fragileWarned: Set<String> = []
    private var laserWarned: Set<String> = []

    private var particlePool: [SKShapeNode] = []
    private var liveParticles = 0
    private var statusTimer: CGFloat = 0
    private var fade: CGFloat = 1
    private var respawning = false
    private let session = GameSession()
    private var tutorial = TutorialController(flags: TutorialFlags())

    func configure(
        level: LevelDefinition,
        appearance: BallAppearance,
        reducedEffects: Bool,
        tutorialFlags: TutorialFlags,
        audio: AudioManager,
        haptics: HapticsManager,
        hapticsEnabled: Bool,
        hud: GameHUDModel,
        onComplete: @escaping (RunResults) -> Void,
        onPromptFlag: @escaping (TutorialFlags) -> Void
    ) {
        self.level = level
        self.appearance = appearance
        self.reducedEffects = reducedEffects
        self.tutorial = TutorialController(flags: tutorialFlags)
        self.audio = audio
        self.haptics = haptics
        self.hapticsEnabled = hapticsEnabled
        self.hud = hud
        self.onComplete = onComplete
        self.onPromptFlag = onPromptFlag
        backgroundColor = SKColor(red: 9/255, green: 13/255, blue: 11/255, alpha: 1)
        anchorPoint = CGPoint(x: 0, y: 0)
        scaleMode = .fill
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        restart()
    }

    func restart() {
        removeAllActions()
        removeAllChildren()
        platformNodes.removeAll()
        anchorNodes.removeAll()
        crystalNodes.removeAll()
        laserBeams.removeAll()
        doorBarriers.removeAll()
        particlePool.removeAll()
        liveParticles = 0
        attachedID = nil
        activeTouch = nil
        attachedThisTouch = false
        candidateID = nil
        recatchTimer = 0
        attachCooldown = 0
        ignoreTouchUntilEnded = false
        reeling = false
        elapsed = 0
        runTime = 0
        attachments = 0
        falls = 0
        collected.removeAll()
        openedDoors.removeAll()
        activatedSwitches.removeAll()
        checkpointReached = false
        checkpointCollected.removeAll()
        checkpointDoors.removeAll()
        checkpointSwitches.removeAll()
        fragileTimers.removeAll()
        fragileBroken.removeAll()
        fragileWarned.removeAll()
        laserWarned.removeAll()
        completing = false
        inputEnabled = true
        fade = 1
        respawning = false
        lastUpdate = 0
        statusTimer = 0
        hud?.statusMessage = nil
        tutorial.reset()
        session.reset(spawn: level.spawn.cg)
        accumulator = 0
        simulationPaused = false

        buildWorld()
        spawnPos = level.spawn.cg
        ballPos = spawnPos
        ballVel = .zero
        checkpointSpawn = spawnPos
        cameraY = min(max(0, spawnPos.y - visibleHeight * 0.28), CGFloat(level.worldHeight) - visibleHeight)
        cameraTargetY = cameraY
        if cameraNode.parent == nil {
            let cam = SKCameraNode()
            camera = cam
            addChild(cam)
        }
        cameraNode.position = CGPoint(x: worldWidth / 2, y: cameraY + visibleHeight / 2)
        updateHUD()
        updateTutorialPrompt()
    }

    private var cameraNode: SKCameraNode { camera ?? SKCameraNode() }

    func cancelActiveTouch(detach: Bool) {
        activeTouch = nil
        candidateID = nil
        aimLine.isHidden = true
        if detach, attachedID != nil {
            attachedID = nil
            royalFingerStart = nil
            audio?.stopRopeAdjust()
        }
        attachedThisTouch = false
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdate == 0 { lastUpdate = currentTime }
        var frameDt = CGFloat(currentTime - lastUpdate)
        lastUpdate = currentTime
        if simulationPaused {
            speed = 0
            return
        }
        speed = 1
        if completing {
            render(CGFloat(min(frameDt, 0.1)))
            return
        }
        if frameDt > 0.1 { frameDt = 0.1 }
        accumulator += frameDt
        let step = GameplayMetrics.simulationStep
        var steps = 0
        while accumulator >= step && steps < GameplayMetrics.maxSimulationSteps {
            simulate(step)
            accumulator -= step
            steps += 1
        }
        if accumulator > step * 2 { accumulator = 0 }
        render(CGFloat(frameDt))
    }

    private var lastUpdate: TimeInterval = 0

    private func simulate(_ dt: CGFloat) {
        elapsed += dt
        if inputEnabled && !completing { runTime += Double(dt) }

        if respawning {
            if fade < 1 {
                fade = min(1, fade + dt / 0.2)
                if fade >= 1 {
                    respawning = false
                    inputEnabled = true
                }
            }
            updateHUD()
            return
        }

        let originBefore = attachedOrigin()
        moveAnchors()
        let originAfter = attachedOrigin()
        if let originBefore, let originAfter {
            let dx = originAfter.x - originBefore.x
            let dy = originAfter.y - originBefore.y
            lastAnchorVelocity = CGVector(dx: dx / dt, dy: dy / dt)
            ballPos.x += dx
            ballPos.y += dy
        } else {
            lastAnchorVelocity = .zero
        }

        if attachedID != nil {
            reelRope(dt)
            adjustRoyalRope(dt)
            ballVel.dy -= GameplayMetrics.gravity * dt
            ballPos.x += ballVel.dx * dt
            ballPos.y += ballVel.dy * dt
            constrainToRope()
            stripRadialVelocity()
            resolvePlatforms()
            constrainToRope()
            stripRadialVelocity()
            if let id = attachedID, let anchor = level.anchors.first(where: { $0.id == id }), anchor.type == .fragile {
                advanceFragile(id, dt)
            }
            tutorial.noteHold(dt, attached: true)
        } else {
            ballVel.dy -= GameplayMetrics.gravity * dt
            ballVel.dx *= max(0, 1 - GameplayMetrics.airDrag * dt)
            ballPos.x += ballVel.dx * dt
            ballPos.y += ballVel.dy * dt
            resolvePlatforms()
            tutorial.noteHold(dt, attached: false)
        }

        clampSpeed()
        clampHorizontal()
        if recatchTimer > 0 { recatchTimer = max(0, recatchTimer - dt) }
        if attachCooldown > 0 { attachCooldown = max(0, attachCooldown - dt) }
        collectCrystals()
        handleSwitches()
        handleLasersAndDoors()
        handleCheckpoint()
        handlePortal()
        handleBounds()
        updateFragileReform(dt)
        updateCamera(dt)
        if statusTimer > 0 {
            statusTimer -= dt
            if statusTimer <= 0 { hud?.statusMessage = nil }
        }
        updateTutorialPrompt()
        updateHUD()
    }

    private func attachedOrigin() -> CGPoint? {
        guard let id = attachedID else { return nil }
        return anchorPosition(id)
    }

    private func constrainToRope() {
        guard let origin = attachedOrigin() else { return }
        var dx = ballPos.x - origin.x
        var dy = ballPos.y - origin.y
        var dist = hypot(dx, dy)
        if dist < 0.001 {
            dx = 0; dy = -1; dist = 1
        }
        let inv = ropeLength / dist
        ballPos = CGPoint(x: origin.x + dx * inv, y: origin.y + dy * inv)
    }

    private func stripRadialVelocity() {
        guard let origin = attachedOrigin() else { return }
        let dx = ballPos.x - origin.x
        let dy = ballPos.y - origin.y
        let dist = max(0.001, hypot(dx, dy))
        let nx = dx / dist
        let ny = dy / dist
        let radial = ballVel.dx * nx + ballVel.dy * ny
        ballVel.dx -= radial * nx
        ballVel.dy -= radial * ny
    }

    private func reelRope(_ dt: CGFloat) {
        guard reeling, attachedID != nil else { return }
        let rest = GameplayMetrics.reelRestLength
        if ropeLength <= rest + 0.5 {
            ropeLength = max(rest, min(ropeLength, GameplayMetrics.maxRope))
            reeling = false
            royalLengthAtAttach = ropeLength
            return
        }
        ropeLength = max(rest, ropeLength - GameplayMetrics.reelSpeed * dt)
        constrainToRope()
    }

    private func clampHorizontal() {
        let minX = ballRadius + 2
        let maxX = worldWidth - ballRadius - 2
        if ballPos.x < minX {
            ballPos.x = minX
            ballVel.dx = abs(ballVel.dx) * 0.2
        } else if ballPos.x > maxX {
            ballPos.x = maxX
            ballVel.dx = -abs(ballVel.dx) * 0.2
        }
    }

    private func clampSpeed() {
        let s = hypot(ballVel.dx, ballVel.dy)
        if s > GameplayMetrics.maxSpeed {
            let k = GameplayMetrics.maxSpeed / s
            ballVel.dx *= k
            ballVel.dy *= k
        }
    }

    private func resolvePlatforms() {
        for platform in level.platforms {
            let rect = platform.rect
            let result = collideCircle(rect: rect)
            ballPos = result.0
            ballVel = result.1
        }
        for door in level.doors where !openedDoors.contains(door.id) {
            let rect = door.rect
            let hit = circleHits(rect: rect)
            if hit {
                hazardRespawn(hazard: true)
                return
            }
        }
    }

    private func collideCircle(rect: CGRect) -> (CGPoint, CGVector) {
        let r = ballRadius
        if rect.contains(ballPos) {
            let up = rect.maxY + r - ballPos.y
            let down = ballPos.y - (rect.minY - r)
            let left = ballPos.x - (rect.minX - r)
            let right = rect.maxX + r - ballPos.x
            let m = min(up, down, left, right)
            if m == up {
                return (CGPoint(x: ballPos.x, y: rect.maxY + r), restOnPlatform(CGVector(dx: ballVel.dx, dy: min(0, ballVel.dy))))
            }
            if m == down { return (CGPoint(x: ballPos.x, y: rect.minY - r), CGVector(dx: ballVel.dx, dy: max(0, ballVel.dy))) }
            if m == left { return (CGPoint(x: rect.minX - r, y: ballPos.y), CGVector(dx: min(0, ballVel.dx), dy: ballVel.dy)) }
            return (CGPoint(x: rect.maxX + r, y: ballPos.y), CGVector(dx: max(0, ballVel.dx), dy: ballVel.dy))
        }
        let nx = min(max(ballPos.x, rect.minX), rect.maxX)
        let ny = min(max(ballPos.y, rect.minY), rect.maxY)
        let dx = ballPos.x - nx
        let dy = ballPos.y - ny
        let d2 = dx * dx + dy * dy
        if d2 > r * r || d2 == 0 { return (ballPos, ballVel) }
        let d = sqrt(d2)
        let ux = dx / d
        let uy = dy / d
        let pos = CGPoint(x: nx + ux * r, y: ny + uy * r)
        var vx = ballVel.dx
        var vy = ballVel.dy
        let vn = vx * ux + vy * uy
        if vn < 0 {
            vx -= vn * ux
            vy -= vn * uy
        }
        if uy > 0.55 {
            vy = min(vy, 0)
            let rested = restOnPlatform(CGVector(dx: vx, dy: vy))
            vx = rested.dx
            vy = rested.dy
        }
        return (pos, CGVector(dx: vx, dy: vy))
    }

    private func restOnPlatform(_ velocity: CGVector) -> CGVector {
        guard attachedID == nil else { return velocity }
        var vx = velocity.dx * GameplayMetrics.platformFriction
        if abs(vx) < 40 { vx = 0 }
        return CGVector(dx: vx, dy: min(0, velocity.dy))
    }

    private func circleHits(rect: CGRect) -> Bool {
        let nx = min(max(ballPos.x, rect.minX), rect.maxX)
        let ny = min(max(ballPos.y, rect.minY), rect.maxY)
        let dx = ballPos.x - nx
        let dy = ballPos.y - ny
        return dx * dx + dy * dy <= ballRadius * ballRadius
    }

    private func collectCrystals() {
        for crystal in level.crystals where !collected.contains(crystal.id) {
            if hypot(ballPos.x - crystal.position.x, ballPos.y - crystal.position.y) <= GameplayMetrics.crystalRadius {
                collected.insert(crystal.id)
                crystalNodes[crystal.id]?.isHidden = true
                audio?.play(.crystal)
                haptics?.crystal(enabled: hapticsEnabled)
                burst(at: crystal.position, color: SKColor(red: 0.72, green: 1, blue: 0, alpha: 1))
                hud?.crystalPulse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                    self?.hud?.crystalPulse = false
                }
            }
        }
    }

    private func handleSwitches() {
        for sw in level.switches where !activatedSwitches.contains(sw.id) {
            if hypot(ballPos.x - sw.x, ballPos.y - sw.y) <= 22 {
                activatedSwitches.insert(sw.id)
                openedDoors.insert(sw.doorId)
                audio?.play(.switchActivate)
                audio?.play(.doorOpen)
                doorBarriers[sw.doorId]?.run(.fadeOut(withDuration: GameplayMetrics.doorOpenTime))
                if let node = children.first(where: { $0.name == "switch-\(sw.id)" }) as? SKSpriteNode {
                    node.color = SKColor(red: 0.72, green: 1, blue: 0, alpha: 1)
                    node.colorBlendFactor = 0.55
                }
            }
        }
    }

    private func handleLasersAndDoors() {
        for laser in level.lasers {
            let cycle = laser.activeDuration + laser.inactiveDuration
            var t = (Double(elapsed) + laser.phase).truncatingRemainder(dividingBy: cycle)
            if t < 0 { t += cycle }
            let inactive = t >= laser.activeDuration
            let timeToActive = inactive ? (cycle - t) : 0
            let warning = inactive && timeToActive <= GameplayMetrics.laserWarnTime
            let active = !inactive
            laserBeams[laser.id]?.isHidden = !active && !warning
            laserBeams[laser.id]?.alpha = active ? 0.95 : 0.35
            if warning && !laserWarned.contains(laser.id) {
                laserWarned.insert(laser.id)
                audio?.play(.fragileWarning, gain: 0.35, rate: 0.85)
            }
            if !warning { laserWarned.remove(laser.id) }
            if active && segmentHitsBall(x1: laser.x1, y1: laser.y1, x2: laser.x2, y2: laser.y2) {
                hazardRespawn(hazard: true)
                return
            }
        }
    }

    private func segmentHitsBall(x1: Double, y1: Double, x2: Double, y2: Double, width: CGFloat = 8) -> Bool {
        let ax = CGFloat(x1), ay = CGFloat(y1), bx = CGFloat(x2), by = CGFloat(y2)
        let abx = bx - ax, aby = by - ay
        let apx = ballPos.x - ax, apy = ballPos.y - ay
        let ab2 = abx * abx + aby * aby
        let t = ab2 == 0 ? 0 : max(0, min(1, (apx * abx + apy * aby) / ab2))
        let cx = ax + abx * t, cy = ay + aby * t
        return hypot(ballPos.x - cx, ballPos.y - cy) <= ballRadius + width / 2
    }

    private func handleCheckpoint() {
        guard !checkpointReached, let cp = level.checkpoint else { return }
        let platformHit = level.platforms.contains { plat in
            plat.rect.maxY + 8 >= cp.y && plat.rect.minY <= cp.y && abs((plat.rect.midX) - cp.x) < plat.width
                && ballPos.y <= plat.rect.maxY + ballRadius + 6
                && ballPos.y >= plat.rect.maxY - 8
                && ballPos.x >= plat.rect.minX && ballPos.x <= plat.rect.maxX
        }
        let near = hypot(ballPos.x - cp.x, ballPos.y - cp.y) < 48
        if (near || platformHit) && ballPos.y > CGFloat(cp.y) - 40 {
            if ballPos.y >= CGFloat(cp.y) - 70 {
                checkpointReached = true
                checkpointSpawn = CGPoint(x: cp.spawnX, y: cp.spawnY)
                checkpointCollected = collected
                checkpointDoors = openedDoors
                checkpointSwitches = activatedSwitches
                fragileBroken.removeAll()
                fragileTimers.removeAll()
                audio?.play(.checkpoint)
                showStatus("Checkpoint reached", 1.5)
                if let beacon = childNode(withName: "checkpoint") {
                    beacon.run(.sequence([.scale(to: 1.12, duration: 0.12), .scale(to: 1.0, duration: 0.2)]))
                }
            }
        }
    }

    private func handlePortal() {
        guard !completing else { return }
        let portal = level.portal.cg
        let nearPortal = hypot(ballPos.x - portal.x, ballPos.y - portal.y) <= GameplayMetrics.portalRadius
        let holdingFinish = attachedID == "a_finish"
        let onExit = level.platforms.contains { plat in
            plat.id == "p_exit"
                && ballPos.x >= plat.rect.minX - 8
                && ballPos.x <= plat.rect.maxX + 8
                && ballPos.y <= plat.rect.maxY + ballRadius + 10
                && ballPos.y >= plat.rect.maxY - 12
        }
        guard nearPortal || onExit || holdingFinish else { return }
        completing = true
        inputEnabled = false
        attachedID = nil
        reeling = false
        audio?.stopRopeAdjust()
        let dest = portal
        let start = ballPos
        run(.customAction(withDuration: 0.45) { [weak self] _, t in
            guard let self else { return }
            let k = min(1, t / 0.45)
            self.ballPos.x = start.x + (dest.x - start.x) * k
            self.ballPos.y = start.y + (dest.y - start.y) * k
            self.ballVel = .zero
        }) {
            [weak self] in self?.emitResults()
        }
    }

    private func emitResults() {
        session.time = runTime
        session.attachments = attachments
        session.falls = falls
        session.collected = collected
        onComplete?(session.results(for: level))
    }

    private func handleBounds() {
        let camBottom = cameraY
        if ballPos.y < camBottom - GameplayMetrics.fallMargin {
            hazardRespawn(hazard: false)
        }
    }

    private func hazardRespawn(hazard: Bool) {
        guard !respawning, !completing else { return }
        falls += 1
        attachedID = nil
        royalFingerStart = nil
        reeling = false
        ignoreTouchUntilEnded = true
        candidateID = nil
        inputEnabled = false
        respawning = true
        audio?.stopRopeAdjust()
        if hazard {
            audio?.play(.hazard)
            haptics?.hazard(enabled: hapticsEnabled)
        }
        let fadeOut = 0.15
        run(.customAction(withDuration: fadeOut) { [weak self] _, t in
            self?.fade = 1 - min(1, t / fadeOut)
        }) { [weak self] in
            guard let self else { return }
            self.collected = self.checkpointReached ? self.checkpointCollected : []
            self.openedDoors = self.checkpointReached ? self.checkpointDoors : []
            self.activatedSwitches = self.checkpointReached ? self.checkpointSwitches : []
            self.fragileBroken.removeAll()
            self.fragileTimers.removeAll()
            self.fragileWarned.removeAll()
            self.refreshCollectiblesAndDoors()
            self.ballPos = self.checkpointReached ? self.checkpointSpawn : self.spawnPos
            self.ballVel = .zero
            self.cameraTargetY = min(max(0, self.ballPos.y - self.visibleHeight * 0.28), CGFloat(self.level.worldHeight) - self.visibleHeight)
            self.cameraY = self.cameraTargetY
            self.audio?.play(.respawn)
            self.showStatus(self.checkpointReached ? "Returned to checkpoint" : "Try that jump again", 1.4)
            self.fade = 0
        }
    }

    private func refreshCollectiblesAndDoors() {
        for crystal in level.crystals {
            crystalNodes[crystal.id]?.isHidden = collected.contains(crystal.id)
        }
        for door in level.doors {
            let open = openedDoors.contains(door.id)
            doorBarriers[door.id]?.removeAllActions()
            doorBarriers[door.id]?.alpha = open ? 0 : 1
            doorBarriers[door.id]?.isHidden = open
        }
        for sw in level.switches {
            guard let node = childNode(withName: "switch-\(sw.id)") as? SKSpriteNode else { continue }
            if activatedSwitches.contains(sw.id) {
                node.color = SKColor(red: 0.72, green: 1, blue: 0, alpha: 1)
                node.colorBlendFactor = 0.55
            } else {
                node.colorBlendFactor = 0
            }
        }
        for (id, node) in anchorNodes {
            node.removeAction(forKey: "hl")
            node.setScale(1)
            node.colorBlendFactor = 0
            node.alpha = fragileBroken[id] == nil ? 1 : 0.15
        }
    }

    private func advanceFragile(_ id: String, _ dt: CGFloat) {
        let t = (fragileTimers[id] ?? 0) + dt
        fragileTimers[id] = t
        if t >= GameplayMetrics.fragileBreakTime - GameplayMetrics.fragileWarningLead, !fragileWarned.contains(id) {
            fragileWarned.insert(id)
            audio?.play(.fragileWarning)
        }
        if t >= GameplayMetrics.fragileBreakTime {
            breakFragile(id)
        }
        if let node = anchorNodes[id] {
            let k = min(1, t / GameplayMetrics.fragileBreakTime)
            node.color = SKColor(red: 1, green: 0.82 - 0.2 * k, blue: 0.39, alpha: 1)
            node.colorBlendFactor = 0.45 * k
        }
    }

    private func breakFragile(_ id: String) {
        audio?.play(.fragileBreak)
        if attachedID == id {
            attachedID = nil
            royalFingerStart = nil
        }
        fragileTimers[id] = 0
        fragileWarned.remove(id)
        fragileBroken[id] = GameplayMetrics.fragileReformTime
        anchorNodes[id]?.alpha = 0.15
    }

    private func updateFragileReform(_ dt: CGFloat) {
        for (id, t) in fragileBroken {
            let next = t - dt
            if next <= 0 {
                fragileBroken.removeValue(forKey: id)
                anchorNodes[id]?.alpha = 1
                anchorNodes[id]?.colorBlendFactor = 0
            } else {
                fragileBroken[id] = next
            }
        }
    }

    private func adjustRoyalRope(_ dt: CGFloat) {
        guard level.usesRoyalWhip, !reeling, let start = royalFingerStart, let touch = activeTouch, let view else {
            audio?.stopRopeAdjust()
            return
        }
        let now = touch.location(in: view)
        let dyPoints = start.y - now.y
        if abs(dyPoints) < GameplayMetrics.royalDeadzonePoints {
            audio?.stopRopeAdjust()
            return
        }
        let adjusted = dyPoints - (dyPoints > 0 ? GameplayMetrics.royalDeadzonePoints : -GameplayMetrics.royalDeadzonePoints)
        let desired = royalLengthAtAttach - adjusted * GameplayMetrics.royalUnitsPerPoint
        let target = min(max(desired, GameplayMetrics.royalMinRope), GameplayMetrics.royalMaxRope)
        let maxDelta = GameplayMetrics.royalMaxLengthChange * dt
        let delta = min(max(target - ropeLength, -maxDelta), maxDelta)
        if abs(delta) < 0.01 {
            audio?.stopRopeAdjust()
            return
        }
        let previous = ropeLength
        ropeLength += delta
        if let origin = attachedOrigin() {
            constrainToRope()
            if overlapsSolid() {
                ropeLength = previous
                constrainToRope()
                audio?.stopRopeAdjust()
                return
            }
            _ = origin
        }
        audio?.startRopeAdjust()
        tutorial.noteRoyalAdjust(attached: true, ropeLength: ropeLength, attachLength: royalLengthAtAttach)
    }

    private func overlapsSolid() -> Bool {
        for platform in level.platforms {
            if circleHits(rect: platform.rect) { return true }
        }
        for door in level.doors where !openedDoors.contains(door.id) {
            if circleHits(rect: door.rect) { return true }
        }
        return false
    }

    private func updateCamera(_ dt: CGFloat) {
        let followY = cameraY + visibleHeight * GameplayMetrics.cameraFollowFraction
        if ballPos.y > followY {
            cameraTargetY = ballPos.y - visibleHeight * GameplayMetrics.cameraFollowFraction
        }
        let maxY = max(0, CGFloat(level.worldHeight) - visibleHeight)
        cameraTargetY = min(max(0, cameraTargetY), maxY)
        if cameraTargetY < cameraY { cameraTargetY = cameraY }
        let k = 1 - exp(-dt / GameplayMetrics.cameraSmooth)
        cameraY += (cameraTargetY - cameraY) * k
        cameraNode.position = CGPoint(x: worldWidth / 2, y: cameraY + visibleHeight / 2)
    }

    private func moveAnchors() {
        for anchor in level.anchors {
            guard let node = anchorNodes[anchor.id] else { continue }
            node.position = anchorPosition(anchor.id) ?? node.position
        }
    }

    private func anchorPosition(_ id: String) -> CGPoint? {
        guard let anchor = level.anchors.first(where: { $0.id == id }) else { return nil }
        if fragileBroken[id] != nil { return nil }
        switch anchor.type {
        case .standard, .fragile:
            return anchor.restPosition()
        case .moving:
            let amp = CGFloat(anchor.amplitude ?? 0)
            let period = max(0.1, CGFloat(anchor.period ?? 2))
            let phase = CGFloat(anchor.phase ?? 0)
            let w = sin(2 * .pi * elapsed / period + phase)
            var p = anchor.restPosition()
            if anchor.axis == .vertical {
                p.y += amp * w
            } else {
                p.x += amp * w
            }
            return p
        case .rotating:
            let c = CGPoint(x: anchor.centerX ?? 0, y: anchor.centerY ?? 0)
            let r = CGFloat(anchor.radius ?? 0)
            let period = max(0.1, CGFloat(anchor.period ?? 3))
            let phase = CGFloat(anchor.phase ?? 0)
            let a = 2 * .pi * elapsed / period + phase
            return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
        }
    }

    // MARK: Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard inputEnabled, !simulationPaused, let touch = touches.first, let view else { return }
        if ignoreTouchUntilEnded { return }
        if activeTouch != nil { return }
        activeTouch = touch
        aimStartView = touch.location(in: view)
        aimCurrentScene = touch.location(in: self)
        attachedThisTouch = false
        candidateID = nil
        tryAttach(fingerView: aimStartView, requireDrag: false)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !ignoreTouchUntilEnded, let touch = activeTouch, touches.contains(touch), let view else { return }
        aimCurrentScene = touch.location(in: self)
        let now = touch.location(in: view)
        tryAttach(fingerView: now, requireDrag: attachedID == nil)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else {
            if ignoreTouchUntilEnded { ignoreTouchUntilEnded = false }
            return
        }
        if attachedID != nil {
            releaseRope()
            recatchTimer = GameplayMetrics.recatchWindow
        }
        activeTouch = nil
        candidateID = nil
        attachedThisTouch = false
        ignoreTouchUntilEnded = false
        aimLine.isHidden = true
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        ignoreTouchUntilEnded = false
        cancelActiveTouch(detach: true)
    }

    private func tryAttach(fingerView: CGPoint, requireDrag: Bool) {
        candidateID = bestCandidate()
        guard attachCooldown <= 0 else { return }
        guard let id = candidateID, id != attachedID else { return }
        if requireDrag {
            let drag = hypot(fingerView.x - aimStartView.x, fingerView.y - aimStartView.y)
            let needed = recatchTimer > 0 ? GameplayMetrics.recatchDragPoints : GameplayMetrics.attachDragPoints
            if drag < needed { return }
        }
        attach(to: id, fingerView: fingerView)
    }

    private func bestCandidate() -> String? {
        var nearestFinger: (String, CGFloat)?
        var nearestCone: (String, CGFloat, CGFloat)?
        let dir = CGVector(dx: aimCurrentScene.x - ballPos.x, dy: aimCurrentScene.y - ballPos.y)
        let mag = hypot(dir.dx, dir.dy)
        let ndx = mag > 4 ? dir.dx / mag : 0
        let ndy = mag > 4 ? dir.dy / mag : 1
        let maxAngle = GameplayMetrics.aimAngleDegrees * .pi / 180
        for anchor in level.anchors {
            guard attachedID != anchor.id, let pos = anchorPosition(anchor.id) else { continue }
            let dx = pos.x - ballPos.x
            let dy = pos.y - ballPos.y
            let dist = hypot(dx, dy)
            guard dist >= GameplayMetrics.minAttachDistance, dist <= GameplayMetrics.attachRange else { continue }
            if blocked(from: ballPos, to: pos) { continue }
            let fingerDist = hypot(pos.x - aimCurrentScene.x, pos.y - aimCurrentScene.y)
            if nearestFinger == nil || fingerDist < nearestFinger!.1 {
                nearestFinger = (anchor.id, fingerDist)
            }
            if mag > 4 {
                let ang = acos(max(-1, min(1, (dx / dist) * ndx + (dy / dist) * ndy)))
                if ang <= maxAngle {
                    if nearestCone == nil || ang < nearestCone!.1 || (ang == nearestCone!.1 && dist < nearestCone!.2) {
                        nearestCone = (anchor.id, ang, dist)
                    }
                }
            }
        }
        if let near = nearestFinger, near.1 <= GameplayMetrics.fingerAimRadius {
            return near.0
        }
        return nearestCone?.0
    }

    private func blocked(from a: CGPoint, to b: CGPoint) -> Bool {
        for door in level.doors where !openedDoors.contains(door.id) {
            if segmentIntersects(a, b, rect: door.rect) { return true }
        }
        return false
    }

    private func segmentIntersects(_ a: CGPoint, _ b: CGPoint, rect: CGRect) -> Bool {
        if rect.contains(a) || rect.contains(b) { return true }
        let pts = [
            (CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY)),
            (CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY)),
            (CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)),
            (CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.minY))
        ]
        return pts.contains { segsIntersect(a, b, $0.0, $0.1) }
    }

    private func segsIntersect(_ p1: CGPoint, _ p2: CGPoint, _ q1: CGPoint, _ q2: CGPoint) -> Bool {
        func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        let d1 = cross(p1, p2, q1)
        let d2 = cross(p1, p2, q2)
        let d3 = cross(q1, q2, p1)
        let d4 = cross(q1, q2, p2)
        return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))
    }

    private func attach(to id: String, fingerView: CGPoint) {
        guard let pos = anchorPosition(id) else { return }
        attachedID = id
        attachedThisTouch = true
        attachments += 1
        recatchTimer = 0
        attachCooldown = GameplayMetrics.attachCooldownTime
        reeling = true
        aimStartView = fingerView
        var length = hypot(ballPos.x - pos.x, ballPos.y - pos.y)
        length = min(max(length, GameplayMetrics.minRope), GameplayMetrics.maxRope)
        ropeLength = length
        royalFingerStart = fingerView
        royalLengthAtAttach = length
        applyAttachBoost(anchor: pos, fingerView: fingerView)
        audio?.play(.whipAttach)
        haptics?.attach(enabled: hapticsEnabled)
        aimLine.isHidden = true
        tutorial.noteAttach(level: level)
    }

    private func applyAttachBoost(anchor: CGPoint, fingerView: CGPoint) {
        let dx = anchor.x - ballPos.x
        let dy = anchor.y - ballPos.y
        let dist = max(0.001, hypot(dx, dy))
        ballVel.dx = ballVel.dx * 0.3 + (dx / dist) * GameplayMetrics.attachBoost
        ballVel.dy = ballVel.dy * 0.3 + (dy / dist) * GameplayMetrics.attachBoost
    }

    private func releaseRope() {
        if let originVel = Optional(lastAnchorVelocity), attachedID != nil {
            ballVel.dx += originVel.dx
            ballVel.dy += originVel.dy
        }
        attachedID = nil
        royalFingerStart = nil
        audio?.play(.whipRelease)
        audio?.stopRopeAdjust()
        tutorial.noteRelease(level: level, ropeLength: ropeLength, attachLength: royalLengthAtAttach)
    }

    // MARK: Render / world

    private func buildWorld() {
        addBackground()
        addDecorations()
        for platform in level.platforms {
            let node = makePlatform(platform.rect)
            node.name = platform.id
            addChild(node)
            platformNodes[platform.id] = node
        }
        for anchor in level.anchors {
            let name: String
            switch anchor.type {
            case .standard: name = "anchor_standard"
            case .moving: name = "anchor_moving"
            case .rotating: name = "anchor_rotating"
            case .fragile: name = "anchor_fragile"
            }
            let sprite = SKSpriteNode(imageNamed: name)
            sprite.size = CGSize(width: 36, height: 36)
            sprite.position = anchor.restPosition()
            sprite.zPosition = 8
            addChild(sprite)
            anchorNodes[anchor.id] = sprite
            if anchor.type == .fragile {
                addFragileCracks(to: sprite)
            }
            if anchor.type == .rotating {
                let orbit = SKShapeNode(circleOfRadius: CGFloat(anchor.radius ?? 40))
                orbit.position = CGPoint(x: anchor.centerX ?? 0, y: anchor.centerY ?? 0)
                orbit.strokeColor = SKColor(white: 1, alpha: 0.16)
                orbit.lineWidth = 1
                orbit.fillColor = .clear
                orbit.zPosition = 2
                addChild(orbit)
            }
        }
        for crystal in level.crystals {
            let sprite = SKSpriteNode(imageNamed: "crystal_pickup")
            sprite.size = CGSize(width: 28, height: 28)
            sprite.position = crystal.position
            sprite.zPosition = 7
            sprite.name = crystal.id
            addChild(sprite)
            crystalNodes[crystal.id] = sprite
        }
        if let cp = level.checkpoint {
            let beacon = SKSpriteNode(imageNamed: "checkpoint_beacon")
            beacon.size = CGSize(width: 28, height: 56)
            beacon.position = CGPoint(x: cp.x, y: cp.y)
            beacon.zPosition = 6
            beacon.name = "checkpoint"
            addChild(beacon)
        }
        for door in level.doors {
            let frame = SKSpriteNode(imageNamed: "energy_door_frame")
            frame.size = CGSize(width: door.width + 16, height: door.height + 12)
            frame.position = CGPoint(x: door.rect.midX, y: door.rect.midY)
            frame.zPosition = 5
            addChild(frame)
            let barrier = SKShapeNode(rectOf: CGSize(width: door.width - 8, height: door.height - 16), cornerRadius: 6)
            barrier.position = frame.position
            barrier.fillColor = SKColor(red: 0.72, green: 1, blue: 0, alpha: 0.35)
            barrier.strokeColor = SKColor(red: 0.72, green: 1, blue: 0, alpha: 0.8)
            barrier.zPosition = 5.1
            addChild(barrier)
            doorBarriers[door.id] = barrier
        }
        for sw in level.switches {
            let sprite = SKSpriteNode(imageNamed: "switch_plate")
            sprite.size = CGSize(width: 32, height: 32)
            sprite.position = CGPoint(x: sw.x, y: sw.y)
            sprite.zPosition = 6
            sprite.name = "switch-\(sw.id)"
            addChild(sprite)
        }
        for laser in level.lasers {
            let a = SKSpriteNode(imageNamed: "laser_emitter")
            a.size = CGSize(width: 26, height: 26)
            a.position = CGPoint(x: laser.x1, y: laser.y1)
            a.zPosition = 6
            let b = SKSpriteNode(imageNamed: "laser_emitter")
            b.size = CGSize(width: 26, height: 26)
            b.position = CGPoint(x: laser.x2, y: laser.y2)
            b.zPosition = 6
            addChild(a); addChild(b)
            let path = CGMutablePath()
            path.move(to: a.position)
            path.addLine(to: b.position)
            let beam = SKShapeNode(path: path)
            beam.strokeColor = SKColor(red: 1, green: 0.39, blue: 0.46, alpha: 1)
            beam.lineWidth = 6
            beam.glowWidth = reducedEffects ? 1 : 8
            beam.zPosition = 5.5
            beam.isHidden = true
            addChild(beam)
            laserBeams[laser.id] = beam
        }
        portalNode = SKSpriteNode(imageNamed: "exit_portal")
        portalNode.size = CGSize(width: 64, height: 96)
        portalNode.position = level.portal.cg
        portalNode.zPosition = 6
        addChild(portalNode)
        portalRing.position = level.portal.cg
        portalRing.strokeColor = SKColor(red: 0.72, green: 1, blue: 0, alpha: 0.55)
        portalRing.fillColor = .clear
        portalRing.lineWidth = 2
        portalRing.zPosition = 6.2
        addChild(portalRing)

        ballNode = SKSpriteNode(imageNamed: "energy_ball")
        ballNode.size = CGSize(width: ballRadius * 2.2, height: ballRadius * 2.2)
        let tint = appearance.tint
        ballNode.color = SKColor(
            red: CGFloat((tint >> 16) & 0xFF) / 255,
            green: CGFloat((tint >> 8) & 0xFF) / 255,
            blue: CGFloat(tint & 0xFF) / 255,
            alpha: 1
        )
        ballNode.colorBlendFactor = 0.55
        ballNode.zPosition = 12
        addChild(ballNode)

        ropeGlow.strokeColor = SKColor(red: 0.72, green: 1, blue: 0, alpha: 0.35)
        ropeGlow.lineWidth = 9
        ropeGlow.zPosition = 9
        ropeCore.strokeColor = SKColor(red: 0.87, green: 1, blue: 0.9, alpha: 0.95)
        ropeCore.lineWidth = 3
        ropeCore.zPosition = 10
        ropePulse.fillColor = SKColor(red: 0.87, green: 1, blue: 0.44, alpha: 1)
        ropePulse.strokeColor = .clear
        ropePulse.zPosition = 11
        aimLine.strokeColor = SKColor(red: 0.53, green: 0.94, blue: 0.75, alpha: 0.85)
        aimLine.lineWidth = 1.5
        aimLine.zPosition = 11
        aimLine.isHidden = true
        addChild(ropeGlow); addChild(ropeCore); addChild(ropePulse); addChild(aimLine)

        let cap = reducedEffects ? 20 : 80
        for _ in 0..<cap {
            let p = SKShapeNode(circleOfRadius: 2)
            p.fillColor = SKColor(red: 0.72, green: 1, blue: 0, alpha: 1)
            p.strokeColor = .clear
            p.isHidden = true
            p.zPosition = 14
            addChild(p)
            particlePool.append(p)
        }
    }

    private func addBackground() {
        let texture = SKTexture(imageNamed: level.wing.backgroundName)
        let h = CGFloat(level.worldHeight) + visibleHeight
        let bg = SKSpriteNode(texture: texture, size: CGSize(width: worldWidth, height: h))
        bg.anchorPoint = CGPoint(x: 0.5, y: 0)
        bg.position = CGPoint(x: worldWidth / 2, y: -40)
        bg.zPosition = -20
        addChild(bg)
    }

    private func addDecorations() {
        var y: CGFloat = 180
        var i = 0
        while y < CGFloat(level.worldHeight) {
            if i % 2 == 0 {
                let col = SKSpriteNode(imageNamed: "palace_column")
                col.size = CGSize(width: 28, height: 160)
                col.position = CGPoint(x: i % 4 == 0 ? 28 : 362, y: y)
                col.alpha = 0.28
                col.zPosition = -8
                addChild(col)
            } else {
                let arch = SKSpriteNode(imageNamed: "palace_arch")
                arch.size = CGSize(width: 90, height: 90)
                arch.position = CGPoint(x: worldWidth / 2, y: y + 40)
                arch.alpha = 0.16
                arch.zPosition = -9
                addChild(arch)
            }
            if i % 3 == 0 {
                let banner = SKSpriteNode(imageNamed: "palace_hanging_banner")
                banner.size = CGSize(width: 22, height: 64)
                banner.position = CGPoint(x: i % 2 == 0 ? 48 : 342, y: y + 70)
                banner.alpha = 0.22
                banner.zPosition = -7
                addChild(banner)
            }
            y += 220
            i += 1
        }
    }

    private func makePlatform(_ rect: CGRect) -> SKShapeNode {
        let node = SKShapeNode(rectOf: rect.size, cornerRadius: 6)
        node.position = CGPoint(x: rect.midX, y: rect.midY)
        node.fillColor = SKColor(red: 0.12, green: 0.14, blue: 0.14, alpha: 1)
        node.strokeColor = SKColor(red: 0.72, green: 1, blue: 0, alpha: 0.85)
        node.lineWidth = 1.6
        node.zPosition = 3
        let shadow = SKShapeNode(rectOf: CGSize(width: rect.width, height: 6), cornerRadius: 3)
        shadow.fillColor = SKColor(white: 0, alpha: 0.35)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -rect.height / 2 - 2)
        node.addChild(shadow)
        return node
    }

    private func addFragileCracks(to sprite: SKSpriteNode) {
        let cracks = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -10, y: 8))
        path.addLine(to: CGPoint(x: -2, y: 1))
        path.addLine(to: CGPoint(x: 6, y: -8))
        path.move(to: CGPoint(x: 8, y: 6))
        path.addLine(to: CGPoint(x: 0, y: -2))
        path.addLine(to: CGPoint(x: -6, y: -7))
        cracks.path = path
        cracks.strokeColor = SKColor(red: 1, green: 0.72, blue: 0.28, alpha: 0.95)
        cracks.lineWidth = 1.5
        cracks.lineCap = .round
        cracks.zPosition = 1
        sprite.addChild(cracks)
    }

    private func render(_ dt: CGFloat) {
        ballNode.position = ballPos
        ballNode.alpha = fade
        if !reducedEffects {
            let s = 1 + 0.05 * sin(elapsed * 3.2)
            ballNode.setScale(s)
        }
        if let origin = attachedOrigin() {
            let path = CGMutablePath()
            path.move(to: origin)
            path.addLine(to: ballPos)
            ropeGlow.path = path
            ropeCore.path = path
            ropeGlow.isHidden = false
            ropeCore.isHidden = false
            ropeGlow.lineWidth = reducedEffects ? 5 : 9
            if reducedEffects {
                ropePulse.isHidden = true
            } else {
                ropePulse.isHidden = false
                let t = (elapsed.truncatingRemainder(dividingBy: 0.7)) / 0.7
                ropePulse.position = CGPoint(
                    x: origin.x + (ballPos.x - origin.x) * t,
                    y: origin.y + (ballPos.y - origin.y) * t
                )
            }
        } else {
            ropeGlow.isHidden = true
            ropeCore.isHidden = true
            ropePulse.isHidden = true
        }
        if activeTouch != nil, let target = candidateID, target != attachedID {
            let path = CGMutablePath()
            path.move(to: ballPos)
            path.addLine(to: aimCurrentScene)
            aimLine.path = path
            aimLine.isHidden = false
        } else {
            aimLine.isHidden = true
        }
        for (id, node) in anchorNodes {
            let targeted = candidateID == id
            node.alpha = fragileBroken[id] == nil ? (node.alpha < 0.2 ? node.alpha : 1) : 0.15
            if node.action(forKey: "hl") == nil {
                let pos = node.position
                let reach = hypot(pos.x - ballPos.x, pos.y - ballPos.y)
                let inReach = attachedID != id
                    && reach >= GameplayMetrics.minAttachDistance
                    && reach <= GameplayMetrics.attachRange
                node.setScale(targeted ? 1.28 : (inReach ? 1.08 : 1.0))
            }
        }
        if !reducedEffects {
            for (id, node) in crystalNodes where !collected.contains(id) {
                node.position.y = CGFloat(level.crystals.first { $0.id == id }?.y ?? 0) + 4 * sin(elapsed * 2 + CGFloat(id.hashValue % 8))
            }
            portalRing.setScale(1 + 0.08 * sin(elapsed * 2))
            portalRing.zRotation += dt * 0.6
        }
        tickParticles(dt)
    }

    private func burst(at p: CGPoint, color: SKColor) {
        let n = reducedEffects ? 6 : 14
        var used = 0
        for node in particlePool where node.isHidden {
            node.isHidden = false
            node.position = p
            node.fillColor = color
            node.alpha = 1
            node.setScale(1)
            let ang = CGFloat.random(in: 0...(2 * .pi))
            let spd = CGFloat.random(in: 40...140)
            node.userData = NSMutableDictionary(dictionary: [
                "vx": spd * Foundation.cos(ang),
                "vy": spd * Foundation.sin(ang),
                "life": 0.35
            ])
            used += 1
            liveParticles += 1
            if used >= n { break }
        }
        liveParticles = min(liveParticles, particlePool.count)
    }

    private func tickParticles(_ dt: CGFloat) {
        for node in particlePool where !node.isHidden {
            let vx = node.userData?["vx"] as? CGFloat ?? 0
            let vy = node.userData?["vy"] as? CGFloat ?? 0
            var life = node.userData?["life"] as? CGFloat ?? 0
            node.position.x += vx * dt
            node.position.y += vy * dt
            life -= dt
            node.alpha = max(0, life / 0.35)
            node.userData?["life"] = life
            if life <= 0 {
                node.isHidden = true
                liveParticles = max(0, liveParticles - 1)
            }
        }
    }

    private func showStatus(_ text: String, _ duration: CGFloat) {
        hud?.statusMessage = text
        statusTimer = duration
    }

    private func updateHUD() {
        hud?.wingName = level.trial ? "Royal Chambers" : level.wing.displayName
        hud?.levelNumber = level.trial ? "Trial" : "Level \(level.displayNumber)"
        hud?.crystals = collected.count
        hud?.time = runTime
        hud?.attachments = attachments
        hud?.attachmentLimit = level.attachmentLimit
        if attachedID != nil && level.usesRoyalWhip {
            hud?.ropeLength = Int(ropeLength.rounded())
        } else {
            hud?.ropeLength = nil
        }
    }

    private func updateTutorialPrompt() {
        if let changed = tutorial.revealMechanic(ifNeeded: level) {
            onPromptFlag?(changed)
        }
        let prompt = tutorial.prompt(
            for: level,
            attached: attachedID != nil,
            attachments: attachments,
            crystals: collected.count,
            ropeLength: ropeLength,
            attachLength: royalLengthAtAttach
        )
        hud?.prompt = prompt.0
        hud?.showJester = prompt.1 && prompt.0 != nil
        if level.id == "N01", tutorial.step == 0, let first = level.anchors.first {
            highlight(first.id)
        }
    }

    private func highlight(_ id: String) {
        if let node = anchorNodes[id], node.action(forKey: "hl") == nil {
            node.run(.repeatForever(.sequence([
                .scale(to: 1.2, duration: 0.4),
                .scale(to: 1.0, duration: 0.4)
            ])), withKey: "hl")
        }
    }
}
