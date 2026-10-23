import SwiftUI
import AVFoundation

/// Owns the clip library: importing audio, editing, and saving to disk.
@MainActor
final class ClipStore: ObservableObject {
    @Published var clips: [Clip] = [] { didSet { save() } }
    @Published var warmupDuration: TimeInterval = 180 { didSet { save() } }
    @Published var importError: String?

    private struct Library: Codable {
        var clips: [Clip]
        var warmupDuration: TimeInterval
    }

    private var isLoading = false

    init() {
        load()
    }

    func clips(in category: ClipCategory) -> [Clip] {
        clips.filter { $0.category == category }
    }

    // MARK: Import

    func importFiles(_ urls: [URL], into category: ClipCategory) {
        var failures: [String] = []
        for url in urls {
            do {
                clips.append(try makeClip(from: url, category: category))
            } catch {
                failures.append(url.lastPathComponent)
            }
        }
        if !failures.isEmpty {
            importError = "Couldn't import: \(failures.joined(separator: ", ")). Make sure the file is a playable audio file (MP3, M4A, WAV, AIFF…) and not copy-protected."
        }
    }

    private func makeClip(from url: URL, category: ClipCategory) throws -> Clip {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
        let fileName = "\(UUID().uuidString).\(ext)"
        let destination = AppPaths.audioDirectory.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: url, to: destination)

        do {
            let duration = try AVAudioPlayer(contentsOf: destination).duration
            guard duration > Clip.minimumLength else { throw CocoaError(.fileReadCorruptFile) }
            return Clip(
                name: url.deletingPathExtension().lastPathComponent,
                fileName: fileName,
                category: category,
                duration: duration,
                startTime: 0,
                endTime: duration
            )
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    // MARK: Editing

    func update(_ clip: Clip) {
        guard let i = clips.firstIndex(where: { $0.id == clip.id }) else { return }
        clips[i] = clip
    }

    func delete(ids: [UUID]) {
        let removed = clips.filter { ids.contains($0.id) }
        clips.removeAll { ids.contains($0.id) }
        // Only remove the audio file once no remaining clip uses it.
        for clip in removed where !clips.contains(where: { $0.fileName == clip.fileName }) {
            try? FileManager.default.removeItem(at: clip.fileURL)
        }
    }

    func duplicate(_ clip: Clip) {
        guard let i = clips.firstIndex(where: { $0.id == clip.id }) else { return }
        var copy = clip
        copy.id = UUID()
        copy.name += " copy"
        clips.insert(copy, at: i + 1)
    }

    /// Cuts a clip in two at `time` (seconds from the start of the source file).
    func split(_ id: UUID, at time: TimeInterval) {
        guard let i = clips.firstIndex(where: { $0.id == id }) else { return }
        var first = clips[i]
        guard time > first.startTime + Clip.minimumLength,
              time < first.endTime - Clip.minimumLength else { return }

        var second = first
        second.id = UUID()
        second.name += " (2)"
        second.startTime = time
        second.fadeIn = 0
        second.fadeOut = min(second.fadeOut, second.playLength / 2)

        first.endTime = time
        first.fadeOut = 0
        first.fadeIn = min(first.fadeIn, first.playLength / 2)

        var updated = clips
        updated[i] = first
        updated.insert(second, at: i + 1)
        clips = updated
    }

    func move(in category: ClipCategory, from source: IndexSet, to destination: Int) {
        var subset = clips(in: category)
        subset.move(fromOffsets: source, toOffset: destination)
        clips = clips.filter { $0.category != category } + subset
    }

    // MARK: Persistence

    private func load() {
        isLoading = true
        defer { isLoading = false }
        guard let data = try? Data(contentsOf: AppPaths.libraryFile),
              let library = try? JSONDecoder().decode(Library.self, from: data) else { return }
        clips = library.clips.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
        warmupDuration = library.warmupDuration
    }

    private func save() {
        guard !isLoading else { return }
        let library = Library(clips: clips, warmupDuration: warmupDuration)
        guard let data = try? JSONEncoder().encode(library) else { return }
        try? data.write(to: AppPaths.libraryFile, options: .atomic)
    }
}
