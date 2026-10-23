import SwiftUI
import AVFoundation

@main
struct RinkMusicApp: App {
    @StateObject private var store = ClipStore()
    @StateObject private var player = PlaybackController()

    init() {
        // .playback keeps audio going when the ringer switch is on silent
        // and (with the "audio" background mode) when the screen locks.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(player)
                .preferredColorScheme(.dark)
        }
    }
}
