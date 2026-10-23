import Foundation
import AVFoundation

/// Plays one clip at a time, applying its trim points, fades and volume.
/// Nothing ever starts on its own: playback begins only from `play` or `startWarmup`.
@MainActor
final class PlaybackController: ObservableObject {
    @Published private(set) var nowPlaying: Clip?
    /// Current playback position in seconds from the start of the source file.
    @Published private(set) var position: TimeInterval = 0
    @Published private(set) var isWarmupRunning = false
    @Published private(set) var warmupRemaining: TimeInterval = 0
    @Published var errorMessage: String?

    var isPlaying: Bool { nowPlaying != nil }

    /// Length of the fade when the operator taps "Fade".
    let stopFadeDuration: TimeInterval = 1.5
    /// Warmup music fades out over this many seconds as the warmup clock runs out.
    let warmupFinalFade: TimeInterval = 3

    private let tickInterval: TimeInterval = 1.0 / 30
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var stopFadeStart: Date?
    private var warmupQueue: [Clip] = []
    private var warmupIndex = 0
    private var warmupEnd: Date?

    /// Plays a single clip once (stinger, goal, penalty, or an editor preview).
    func play(_ clip: Clip, from offset: TimeInterval? = nil) {
        endWarmup()
        startClip(clip, from: offset)
    }

    /// Starts the warmup clock. Warmup clips play back to back, then everything
    /// fades out when `duration` (3:00 by default) has elapsed.
    func startWarmup(clips: [Clip], duration: TimeInterval, startingAt index: Int = 0) {
        let queue = clips.filter { $0.playLength >= Clip.minimumLength }
        guard !queue.isEmpty else { return }
        warmupQueue = queue
        warmupIndex = min(max(0, index), queue.count - 1)
        warmupEnd = Date().addingTimeInterval(duration)
        warmupRemaining = duration
        isWarmupRunning = true
        startClip(queue[warmupIndex], from: nil)
    }

    func stop(fade: Bool) {
        guard player != nil, fade else { reset(); return }
        if stopFadeStart == nil { stopFadeStart = Date() }
    }

    /// Lets the clip editor change volume/fades/end point of a clip while it's previewing.
    func updateLive(_ clip: Clip) {
        guard nowPlaying?.id == clip.id else { return }
        nowPlaying = clip
    }

    // MARK: Internals

    private func startClip(_ clip: Clip, from offset: TimeInterval?) {
        player?.stop()
        stopFadeStart = nil
        do {
            let p = try AVAudioPlayer(contentsOf: clip.fileURL)
            p.prepareToPlay()
            let start = min(max(offset ?? clip.startTime, clip.startTime), clip.endTime)
            p.currentTime = start
            p.volume = gain(for: clip, at: start) * warmupGain()
            p.play()
            player = p
            nowPlaying = clip
            position = start
            startTimer()
        } catch {
            errorMessage = "Couldn't play \"\(clip.name)\": \(error.localizedDescription)"
            reset()
        }
    }

    private func startTimer() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard let player, let clip = nowPlaying else { return }
        let t = player.currentTime
        position = t

        if let warmupEnd {
            let remaining = warmupEnd.timeIntervalSinceNow
            warmupRemaining = max(0, remaining)
            if remaining <= 0 { reset(); return }
        }

        var g = gain(for: clip, at: t) * warmupGain()
        if let stopFadeStart {
            let progress = Date().timeIntervalSince(stopFadeStart) / stopFadeDuration
            if progress >= 1 { reset(); return }
            g *= Float(1 - progress)
        }

        if t >= clip.endTime || !player.isPlaying {
            clipFinished()
            return
        }
        // Ramp to the new level over one tick so volume changes are smooth.
        player.setVolume(g, fadeDuration: tickInterval)
    }

    private func clipFinished() {
        if isWarmupRunning, stopFadeStart == nil, !warmupQueue.isEmpty {
            warmupIndex = (warmupIndex + 1) % warmupQueue.count
            startClip(warmupQueue[warmupIndex], from: nil)
        } else {
            reset()
        }
    }

    /// The clip's own fade-in / fade-out envelope times its volume.
    private func gain(for clip: Clip, at t: TimeInterval) -> Float {
        var g = 1.0
        if clip.fadeIn > 0 { g = min(g, (t - clip.startTime) / clip.fadeIn) }
        if clip.fadeOut > 0 { g = min(g, (clip.endTime - t) / clip.fadeOut) }
        return Float(min(1, max(0, g))) * clip.volume
    }

    private func warmupGain() -> Float {
        guard let warmupEnd else { return 1 }
        return Float(min(1, max(0, warmupEnd.timeIntervalSinceNow / warmupFinalFade)))
    }

    private func reset() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
        nowPlaying = nil
        stopFadeStart = nil
        endWarmup()
    }

    private func endWarmup() {
        isWarmupRunning = false
        warmupEnd = nil
        warmupQueue = []
        warmupRemaining = 0
    }
}
