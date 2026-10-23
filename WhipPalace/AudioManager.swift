import AVFoundation
import Foundation
import Combine

final class AudioManager: ObservableObject {
    enum MusicTrack: Equatable {
        case menu
        case wing(Wing)
        case none

        var resourceName: String? {
            switch self {
            case .menu: return "music_menu"
            case .wing(let wing): return wing.musicName
            case .none: return nil
            }
        }
    }

    enum Effect: String, CaseIterable {
        case uiTap = "sfx_ui_tap"
        case uiSelect = "sfx_ui_select"
        case uiBlocked = "sfx_ui_blocked"
        case whipAttach = "sfx_whip_attach"
        case whipRelease = "sfx_whip_release"
        case ropeAdjust = "sfx_rope_adjust"
        case crystal = "sfx_crystal_collect"
        case checkpoint = "sfx_checkpoint"
        case hazard = "sfx_hazard_hit"
        case respawn = "sfx_respawn"
        case fragileWarning = "sfx_fragile_warning"
        case fragileBreak = "sfx_fragile_break"
        case switchActivate = "sfx_switch_activate"
        case doorOpen = "sfx_door_open"
        case levelComplete = "sfx_level_complete"
    }

    private var settings: AppSettings
    private var musicA: AVAudioPlayer?
    private var musicB: AVAudioPlayer?
    private var usingA = true
    private var currentTrack: MusicTrack = .none
    private var effectPool: [Effect: [AVAudioPlayer]] = [:]
    private var ropeAdjustPlayer: AVAudioPlayer?
    private var fadeTimer: Timer?
    private var fadeStep = 0
    private var musicPausedForGameplay = false

    init() {
        settings = .defaultSettings
        configureSession()
    }

    func loadReferences() {
        configureSession()
        for effect in Effect.allCases {
            _ = players(for: effect)
        }
        _ = makeMusicPlayer(named: MusicTrack.menu.resourceName ?? "music_menu")
        ropeAdjustPlayer = makeEffectPlayer(named: Effect.ropeAdjust.rawValue, ext: "wav")
        ropeAdjustPlayer?.numberOfLoops = -1
    }

    func apply(settings: AppSettings) {
        self.settings = settings
        let musicVol = settings.musicEnabled ? Float(settings.musicVolume) : 0
        activeMusicPlayer()?.volume = musicVol
        idleMusicPlayer()?.volume = 0
        if let player = ropeAdjustPlayer, player.isPlaying {
            player.volume = settings.effectsEnabled ? Float(settings.effectsVolume) * 0.35 : 0
        }
        if !settings.musicEnabled {
            activeMusicPlayer()?.pause()
        } else if currentTrack != .none, !musicPausedForGameplay, activeMusicPlayer()?.isPlaying == false {
            activeMusicPlayer()?.play()
        }
    }

    func playMenuMusic() {
        musicPausedForGameplay = false
        playMusic(.menu)
    }

    func playGameplayMusic(for level: LevelDefinition) {
        musicPausedForGameplay = false
        if level.trial || level.wing == .royal {
            playMusic(.wing(.royal))
        } else {
            playMusic(.wing(level.wing))
        }
    }

    func pauseGameplayMusic() {
        musicPausedForGameplay = true
        activeMusicPlayer()?.pause()
        stopRopeAdjust()
    }

    func resumeGameplayMusic() {
        guard settings.musicEnabled else { return }
        musicPausedForGameplay = false
        activeMusicPlayer()?.play()
    }

    func stopMusic() {
        currentTrack = .none
        musicA?.stop()
        musicB?.stop()
        fadeTimer?.invalidate()
    }

    func handleBackground() {
        activeMusicPlayer()?.pause()
        idleMusicPlayer()?.pause()
        stopRopeAdjust()
        stopAllEffects()
    }

    func play(_ effect: Effect, gain: Float = 1, rate: Float = 1) {
        guard settings.effectsEnabled, effect != .ropeAdjust else { return }
        guard let player = idlePlayer(for: effect) else { return }
        player.volume = Float(settings.effectsVolume) * gain
        player.enableRate = true
        player.rate = rate
        player.currentTime = 0
        player.play()
    }

    func startRopeAdjust() {
        guard settings.effectsEnabled else { return }
        guard let player = ropeAdjustPlayer else { return }
        player.volume = Float(settings.effectsVolume) * 0.35
        if !player.isPlaying {
            player.currentTime = 0
            player.play()
        }
    }

    func stopRopeAdjust() {
        guard let player = ropeAdjustPlayer, player.isPlaying else { return }
        player.stop()
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func playMusic(_ track: MusicTrack) {
        guard currentTrack != track else {
            if settings.musicEnabled, !musicPausedForGameplay, activeMusicPlayer()?.isPlaying == false {
                activeMusicPlayer()?.play()
            }
            return
        }
        guard let name = track.resourceName, let incoming = makeMusicPlayer(named: name) else { return }
        incoming.numberOfLoops = -1
        incoming.volume = 0
        incoming.currentTime = 0
        if settings.musicEnabled {
            incoming.play()
        }
        let outgoing = activeMusicPlayer()
        if usingA {
            musicB = incoming
        } else {
            musicA = incoming
        }
        usingA.toggle()
        currentTrack = track
        crossfade(from: outgoing, to: incoming)
    }

    private func crossfade(from outgoing: AVAudioPlayer?, to incoming: AVAudioPlayer) {
        fadeTimer?.invalidate()
        let target = settings.musicEnabled ? Float(settings.musicVolume) : 0
        let steps = 8
        let interval = GameplayMetrics.musicCrossfade / Double(steps)
        fadeStep = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.fadeStep += 1
            let t = Float(self.fadeStep) / Float(steps)
            incoming.volume = target * t
            outgoing?.volume = target * (1 - t)
            if self.fadeStep >= steps {
                timer.invalidate()
                outgoing?.stop()
                incoming.volume = target
            }
        }
    }

    private func activeMusicPlayer() -> AVAudioPlayer? {
        currentTrack == .none ? nil : (usingA ? musicA : musicB)
    }

    private func idleMusicPlayer() -> AVAudioPlayer? {
        currentTrack == .none ? nil : (usingA ? musicB : musicA)
    }

    private func players(for effect: Effect) -> [AVAudioPlayer] {
        if let existing = effectPool[effect] { return existing }
        let count = effect == .ropeAdjust ? 1 : 8
        var list: [AVAudioPlayer] = []
        for _ in 0..<count {
            if let player = makeEffectPlayer(named: effect.rawValue, ext: "wav") {
                list.append(player)
            }
        }
        effectPool[effect] = list
        return list
    }

    private func idlePlayer(for effect: Effect) -> AVAudioPlayer? {
        let list = players(for: effect)
        if let idle = list.first(where: { !$0.isPlaying }) { return idle }
        return list.first
    }

    private func stopAllEffects() {
        for list in effectPool.values {
            list.forEach { $0.stop() }
        }
    }

    private func makeMusicPlayer(named name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a") else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }

    private func makeEffectPlayer(named name: String, ext: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }
}
