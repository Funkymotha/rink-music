import SwiftUI

enum ClipCategory: String, Codable, CaseIterable, Identifiable {
    case warmup, stinger, goal, penalty

    var id: String { rawValue }

    var title: String {
        switch self {
        case .warmup: return "Warmup"
        case .stinger: return "Stinger"
        case .goal: return "Goal"
        case .penalty: return "Penalty"
        }
    }

    var systemImage: String {
        switch self {
        case .warmup: return "figure.hockey"
        case .stinger: return "bolt.fill"
        case .goal: return "sparkles"
        case .penalty: return "hand.raised.fill"
        }
    }

    var color: Color {
        switch self {
        case .warmup: return .blue
        case .stinger: return .orange
        case .goal: return .red
        case .penalty: return .purple
        }
    }
}

struct Clip: Identifiable, Codable, Equatable {
    static let minimumLength: TimeInterval = 0.5

    var id = UUID()
    var name: String
    /// File name inside `AppPaths.audioDirectory`. Several clips may share one file (e.g. after a split).
    var fileName: String
    var category: ClipCategory
    /// Full length of the source audio file.
    var duration: TimeInterval
    /// Trim points, in seconds from the beginning of the source file.
    var startTime: TimeInterval
    var endTime: TimeInterval
    var fadeIn: TimeInterval = 0
    var fadeOut: TimeInterval = 0
    /// 0...1
    var volume: Float = 1

    var playLength: TimeInterval { max(0, endTime - startTime) }
    var fileURL: URL { AppPaths.audioDirectory.appendingPathComponent(fileName) }
}

enum AppPaths {
    static let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    static let audioDirectory: URL = {
        let url = documents.appendingPathComponent("Audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static let libraryFile = documents.appendingPathComponent("library.json")
}

extension TimeInterval {
    /// 2:05
    var mmss: String {
        let t = Int(Swift.max(0, self.rounded(.down)))
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    /// 2:05.3
    var mmssTenths: String {
        let t = Swift.max(0, self)
        let m = Int(t) / 60
        return String(format: "%d:%04.1f", m, t - Double(m * 60))
    }
}
