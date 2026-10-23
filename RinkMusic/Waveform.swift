import SwiftUI
import AVFoundation

enum Waveform {
    @MainActor private static var cache: [String: [Float]] = [:]

    /// Normalized (0...1) peak levels for `buckets` evenly spaced slices of the file.
    @MainActor
    static func load(_ url: URL, buckets: Int = 300) async -> [Float] {
        let key = "\(url.lastPathComponent)#\(buckets)"
        if let cached = cache[key] { return cached }
        let peaks = await Task.detached(priority: .userInitiated) {
            compute(url: url, buckets: buckets)
        }.value
        cache[key] = peaks
        return peaks
    }

    static func compute(url: URL, buckets: Int) -> [Float] {
        guard let file = try? AVAudioFile(forReading: url), file.length > 0 else { return [] }
        let framesPerBucket = AVAudioFrameCount(max(1, file.length / AVAudioFramePosition(buckets)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: framesPerBucket) else { return [] }
        var peaks: [Float] = []
        peaks.reserveCapacity(buckets)
        while peaks.count < buckets {
            do { try file.read(into: buffer, frameCount: framesPerBucket) } catch { break }
            let n = Int(buffer.frameLength)
            guard n > 0, let channels = buffer.floatChannelData else { break }
            var peak: Float = 0
            for ch in 0..<Int(buffer.format.channelCount) {
                let samples = channels[ch]
                var i = 0
                while i < n {
                    peak = max(peak, abs(samples[i]))
                    i += 4
                }
            }
            peaks.append(peak)
        }
        let loudest = peaks.max() ?? 0
        return loudest > 0 ? peaks.map { $0 / loudest } : peaks
    }
}

struct WaveformShape: Shape {
    let samples: [Float]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !samples.isEmpty else {
            path.addRect(CGRect(x: 0, y: rect.midY - 0.5, width: rect.width, height: 1))
            return path
        }
        let barWidth = rect.width / CGFloat(samples.count)
        for (i, s) in samples.enumerated() {
            let h = max(1, CGFloat(s) * rect.height)
            path.addRect(CGRect(x: CGFloat(i) * barWidth, y: rect.midY - h / 2,
                                width: max(1, barWidth * 0.75), height: h))
        }
        return path
    }
}

/// Waveform with draggable start/end handles, the fade/volume envelope, and a playhead.
struct WaveformEditor: View {
    let samples: [Float]
    @Binding var clip: Clip
    @Binding var playhead: TimeInterval
    let tint: Color

    private let space = "waveform"

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let total = max(clip.duration, 0.01)
            let x = { (t: TimeInterval) -> CGFloat in CGFloat(t / total) * w }
            let time = { (px: CGFloat) -> TimeInterval in min(max(0, TimeInterval(px / w) * total), total) }
            let startX = x(clip.startTime)
            let endX = x(clip.endTime)

            ZStack(alignment: .topLeading) {
                // Whole file, dimmed; tap or drag to move the playhead.
                WaveformShape(samples: samples)
                    .fill(Color.secondary.opacity(0.3))
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(space))
                        .onChanged { playhead = time($0.location.x) })

                // Kept region, highlighted.
                WaveformShape(samples: samples)
                    .fill(tint)
                    .mask {
                        HStack(spacing: 0) {
                            Color.clear.frame(width: startX)
                            Rectangle().frame(width: max(0, endX - startX))
                            Spacer(minLength: 0)
                        }
                    }
                    .allowsHitTesting(false)

                envelope(startX: startX, endX: endX, x: x, h: h)
                    .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                    .allowsHitTesting(false)

                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 2, height: h)
                    .position(x: x(playhead), y: h / 2)
                    .allowsHitTesting(false)

                // Apply the gesture before .position so only the handle itself is draggable.
                handle(height: h)
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(space))
                        .onChanged { v in
                            clip.startTime = min(time(v.location.x), clip.endTime - Clip.minimumLength)
                        })
                    .position(x: startX, y: h / 2)

                handle(height: h)
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(space))
                        .onChanged { v in
                            clip.endTime = max(time(v.location.x), clip.startTime + Clip.minimumLength)
                        })
                    .position(x: endX, y: h / 2)
            }
            .coordinateSpace(.named(space))
        }
    }

    /// Line showing the gain over time: ramps for the fades, height for the volume.
    private func envelope(startX: CGFloat, endX: CGFloat, x: (TimeInterval) -> CGFloat, h: CGFloat) -> Path {
        let top = h * CGFloat(1 - clip.volume) + 2
        let fadeInEnd = x(clip.startTime + clip.fadeIn)
        let fadeOutStart = x(clip.endTime - clip.fadeOut)
        var p = Path()
        p.move(to: CGPoint(x: startX, y: clip.fadeIn > 0 ? h : top))
        p.addLine(to: CGPoint(x: fadeInEnd, y: top))
        p.addLine(to: CGPoint(x: fadeOutStart, y: top))
        p.addLine(to: CGPoint(x: endX, y: clip.fadeOut > 0 ? h : top))
        return p
    }

    private func handle(height: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(Color.white).frame(width: 3, height: height)
            Capsule().fill(Color.white).frame(width: 14, height: 30)
        }
        .frame(width: 36, height: height)
        .contentShape(Rectangle())
    }
}
