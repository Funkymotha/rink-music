import SwiftUI
import UniformTypeIdentifiers

/// The clip list for one section (Warmup, Stinger, Goal, Penalty).
struct CategoryView: View {
    let category: ClipCategory
    @EnvironmentObject private var store: ClipStore
    @EnvironmentObject private var player: PlaybackController
    @State private var showImporter = false
    @State private var editing: Clip?

    private var clips: [Clip] { store.clips(in: category) }

    var body: some View {
        List {
            if category == .warmup {
                Section { WarmupPanel(clips: clips) }
            } else if clips.count > 1 {
                Section {
                    Button {
                        let others = clips.filter { $0.id != player.nowPlaying?.id }
                        if let pick = others.randomElement() { player.play(pick) }
                    } label: {
                        Label("Play Random \(category.title)", systemImage: "shuffle")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(category.color)
                    .controlSize(.large)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }

            Section {
                if clips.isEmpty {
                    emptyState
                }
                ForEach(clips) { clip in
                    ClipRow(clip: clip,
                            tint: category.color,
                            isPlaying: player.nowPlaying?.id == clip.id,
                            onPlay: { tap(clip) },
                            onEdit: { editing = clip })
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { delete([clip.id]) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { store.duplicate(clip) } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        .tint(.gray)
                    }
                }
                .onMove { store.move(in: category, from: $0, to: $1) }
                .onDelete { offsets in delete(offsets.map { clips[$0].id }) }
            } header: {
                Text(category == .warmup ? "Warmup playlist (plays in order)" : "\(clips.count) clips — tap to play")
            } footer: {
                if clips.count > 1 {
                    Text("To change the order, tap Edit and drag clips by their ≡ handles.")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showImporter = true } label: { Label("Import", systemImage: "plus") }
            }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.audio],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): store.importFiles(urls, into: category)
            case .failure(let error): store.importError = error.localizedDescription
            }
        }
        .sheet(item: $editing) { clip in
            ClipEditorView(clip: clip)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list").font(.largeTitle).foregroundStyle(.secondary)
            Text("No \(category.title.lowercased()) clips yet").font(.headline)
            Text("Tap + to import audio files from the Files app (iCloud Drive, On My iPhone, Dropbox, etc.).")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Import Audio") { showImporter = true }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func tap(_ clip: Clip) {
        if player.nowPlaying?.id == clip.id {
            player.stop(fade: true)
        } else if category == .warmup {
            let index = clips.firstIndex(where: { $0.id == clip.id }) ?? 0
            player.startWarmup(clips: clips, duration: store.warmupDuration, startingAt: index)
        } else {
            player.play(clip)
        }
    }

    private func delete(_ ids: [UUID]) {
        if let playing = player.nowPlaying, ids.contains(playing.id) {
            player.stop(fade: false)
        }
        store.delete(ids: ids)
    }
}

struct WarmupPanel: View {
    let clips: [Clip]
    @EnvironmentObject private var store: ClipStore
    @EnvironmentObject private var player: PlaybackController

    var body: some View {
        VStack(spacing: 12) {
            if player.isWarmupRunning {
                Text(player.warmupRemaining.mmss)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("left in warmup").foregroundStyle(.secondary)
                Button {
                    player.stop(fade: true)
                } label: {
                    Label("Fade Out Warmup", systemImage: "speaker.wave.1.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                stopButton
            } else {
                Button {
                    player.startWarmup(clips: clips, duration: store.warmupDuration)
                } label: {
                    Label("Start Warmup (\(store.warmupDuration.mmss))", systemImage: "play.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(ClipCategory.warmup.color)
                .controlSize(.large)
                .disabled(clips.isEmpty)
                stopButton

                Stepper(value: $store.warmupDuration, in: 30...1800, step: 15) {
                    Text("Warmup length: \(store.warmupDuration.mmss)").monospacedDigit()
                }
                Text("Plays the warmup clips below in order and fades out when the time is up. Tap a clip to start the warmup from that clip.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    /// Stops whatever is playing in any section, immediately.
    private var stopButton: some View {
        Button(role: .destructive) {
            player.stop(fade: false)
        } label: {
            Label("Stop", systemImage: "stop.fill")
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .controlSize(.large)
        .disabled(!player.isPlaying)
    }
}

struct ClipRow: View {
    let clip: Clip
    let tint: Color
    let isPlaying: Bool
    let onPlay: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isPlaying ? "speaker.wave.3.fill" : "play.circle.fill")
                .font(.title)
                .foregroundStyle(tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(clip.name).font(.headline).lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(clip.startTime.mmssTenths)–\(clip.endTime.mmssTenths)")
                    Text("\(clip.playLength.mmss)").bold()
                    if clip.fadeIn > 0 { Image(systemName: "arrow.up.right") }
                    if clip.fadeOut > 0 { Image(systemName: "arrow.down.right") }
                    if clip.volume < 0.995 { Text("\(Int((clip.volume * 100).rounded()))%") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            Spacer()
            Button(action: onEdit) {
                Image(systemName: "slider.horizontal.3").font(.title3)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onPlay)
        .listRowBackground(isPlaying ? tint.opacity(0.25) : nil)
    }
}
