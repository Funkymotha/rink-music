import SwiftUI

struct NowPlayingBar: View {
    @EnvironmentObject private var player: PlaybackController

    var body: some View {
        if let clip = player.nowPlaying {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: clip.category.systemImage)
                        .font(.title2)
                        .foregroundStyle(clip.category.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(clip.name).font(.headline).lineLimit(1)
                        Text(subtitle(for: clip))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Spacer()
                    Button {
                        player.stop(fade: true)
                    } label: {
                        Text("FADE")
                            .font(.subheadline.bold())
                            .frame(width: 64, height: 56)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemFill)))
                    }
                    Button {
                        player.stop(fade: false)
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 56)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.red))
                    }
                }
                .buttonStyle(.plain)
                ProgressView(value: progress(for: clip))
                    .tint(clip.category.color)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private func progress(for clip: Clip) -> Double {
        guard clip.playLength > 0 else { return 0 }
        return min(1, max(0, (player.position - clip.startTime) / clip.playLength))
    }

    private func subtitle(for clip: Clip) -> String {
        let remaining = (clip.endTime - player.position).mmss
        if player.isWarmupRunning {
            return "\(remaining) left in song · warmup ends in \(player.warmupRemaining.mmss)"
        }
        return "\(remaining) remaining"
    }
}
