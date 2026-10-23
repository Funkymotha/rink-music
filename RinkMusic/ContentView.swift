import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ClipStore
    @EnvironmentObject private var player: PlaybackController
    @State private var category: ClipCategory = .warmup

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryPicker
                CategoryView(category: category)
            }
            .navigationTitle("Rink Music")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { NowPlayingBar() }
        }
        .alert("Import Problem", isPresented: Binding(
            get: { store.importError != nil },
            set: { if !$0 { store.importError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.importError ?? "")
        }
        .alert("Playback Problem", isPresented: Binding(
            get: { player.errorMessage != nil },
            set: { if !$0 { player.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(player.errorMessage ?? "")
        }
    }

    private var categoryPicker: some View {
        HStack(spacing: 8) {
            ForEach(ClipCategory.allCases) { c in
                let selected = c == category
                Button {
                    category = c
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: c.systemImage).font(.title2)
                        Text(c.title).font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selected ? Color.white : Color.primary)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(selected ? c.color : Color(.secondarySystemBackground)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
