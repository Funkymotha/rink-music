import SwiftUI

/// Timeline editor: trim start/end, split, fades and volume, with live preview.
struct ClipEditorView: View {
    @EnvironmentObject private var store: ClipStore
    @EnvironmentObject private var player: PlaybackController
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Clip
    @State private var playhead: TimeInterval
    @State private var samples: [Float] = []

    init(clip: Clip) {
        _draft = State(initialValue: clip)
        _playhead = State(initialValue: clip.startTime)
    }

    private var isPreviewing: Bool { player.nowPlaying?.id == draft.id }
    private var maxFade: TimeInterval { max(0.1, min(15, draft.playLength / 2)) }
    private var canSplit: Bool {
        playhead > draft.startTime + Clip.minimumLength && playhead < draft.endTime - Clip.minimumLength
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $draft.name)
                    Picker("Section", selection: $draft.category) {
                        ForEach(ClipCategory.allCases) { Text($0.title).tag($0) }
                    }
                }

                Section {
                    WaveformEditor(samples: samples, clip: $draft, playhead: $playhead, tint: draft.category.color)
                        .frame(height: 140)
                        .padding(.vertical, 8)

                    HStack {
                        Text("Playhead \(playhead.mmssTenths)")
                        Spacer()
                        Text("Clip length \(draft.playLength.mmssTenths)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                    previewButtons

                    timeRow("Start", value: $draft.startTime,
                            range: 0...(draft.endTime - Clip.minimumLength))
                    timeRow("End", value: $draft.endTime,
                            range: (draft.startTime + Clip.minimumLength)...draft.duration)

                    Button {
                        store.update(draft)
                        store.split(draft.id, at: playhead)
                        finish()
                    } label: {
                        Label("Split Clip at Playhead", systemImage: "scissors")
                    }
                    .disabled(!canSplit)
                } header: {
                    Text("Timeline")
                } footer: {
                    Text("Drag the white handles to trim. Tap or drag the waveform to move the yellow playhead. Splitting cuts this clip into two clips at the playhead.")
                }

                Section("Fades") {
                    sliderRow("Fade in", value: $draft.fadeIn, range: 0...maxFade)
                    sliderRow("Fade out", value: $draft.fadeOut, range: 0...maxFade)
                }

                Section("Volume") {
                    HStack {
                        Image(systemName: "speaker.fill")
                        Slider(value: $draft.volume, in: 0...1)
                        Text("\(Int((draft.volume * 100).rounded()))%")
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }
            .navigationTitle("Edit Clip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { finish() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.update(draft)
                        finish()
                    }
                    .bold()
                }
            }
            .task { samples = await Waveform.load(draft.fileURL) }
            .onChange(of: draft) {
                clampFades()
                player.updateLive(draft)
            }
            .onChange(of: player.position) {
                if isPreviewing { playhead = player.position }
            }
        }
    }

    private var previewButtons: some View {
        HStack(spacing: 12) {
            if isPreviewing {
                Button {
                    player.stop(fade: false)
                } label: {
                    Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
                }
                .tint(.red)
            } else {
                Button {
                    player.play(draft)
                } label: {
                    Label("Preview", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                Button {
                    player.play(draft, from: playhead)
                } label: {
                    Label("From Playhead", systemImage: "play").frame(maxWidth: .infinity)
                }
            }
        }
        .buttonStyle(.bordered)
    }

    private func timeRow(_ label: String, value: Binding<TimeInterval>, range: ClosedRange<TimeInterval>) -> some View {
        HStack(spacing: 10) {
            Text(label).frame(width: 44, alignment: .leading)
            Button {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - 0.1)
            } label: {
                Image(systemName: "minus.circle.fill").font(.title3)
            }
            Text(value.wrappedValue.mmssTenths)
                .monospacedDigit()
                .frame(minWidth: 60)
            Button {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + 0.1)
            } label: {
                Image(systemName: "plus.circle.fill").font(.title3)
            }
            Spacer()
            Button("Set to Playhead") {
                value.wrappedValue = min(max(playhead, range.lowerBound), range.upperBound)
            }
            .font(.footnote)
        }
        .buttonStyle(.borderless)
    }

    private func sliderRow(_ label: String, value: Binding<TimeInterval>, range: ClosedRange<TimeInterval>) -> some View {
        HStack {
            Text(label).frame(width: 72, alignment: .leading)
            Slider(value: value, in: range, step: 0.1)
            Text(String(format: "%.1fs", value.wrappedValue))
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)
        }
    }

    private func clampFades() {
        if draft.fadeIn > maxFade { draft.fadeIn = maxFade }
        if draft.fadeOut > maxFade { draft.fadeOut = maxFade }
    }

    private func finish() {
        if isPreviewing { player.stop(fade: false) }
        dismiss()
    }
}
