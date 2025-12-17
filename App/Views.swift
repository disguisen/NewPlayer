#if canImport(SwiftUI)
import SwiftUI
import Library
import Player
import Common

struct RootView: View {
    @StateObject private var viewModel = LibraryViewModel()

    var body: some View {
        NavigationStack {
            List(viewModel.items) { item in
                NavigationLink(destination: PlayerDetailView(item: item)) {
                    VStack(alignment: .leading) {
                        Text(item.title)
                        Text(item.type.rawValue).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Library")
            .task { await viewModel.load() }
        }
    }
}

final class LibraryViewModel: ObservableObject {
    @Published var items: [MediaItem] = []
    private let service = LibraryService()

    func load() async {
        await service.refresh(sources: [])
        await MainActor.run { self.items = service.items }
    }
}

struct PlayerDetailView: View {
    let item: MediaItem
    @StateObject private var viewModel = PlayerViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text(item.title).font(.title)
            Text("Playback state: \(viewModel.state.isPlaying ? "Playing" : "Paused")")
            HStack {
                Button("Play") { viewModel.play(item: item) }
                Button("Pause") { viewModel.pause() }
            }
            Slider(value: Binding(get: {
                viewModel.state.currentTime
            }, set: { newValue in
                viewModel.seek(to: newValue)
            }), in: 0...(viewModel.state.duration > 0 ? viewModel.state.duration : 100))
        }
        .padding()
        .onAppear { viewModel.load(item: item) }
    }
}

final class PlayerViewModel: ObservableObject, PlayerEngineDelegate {
    @Published var state = PlaybackState(isPlaying: false, currentTime: 0, duration: 0, buffered: 0, rate: 1)
    private let engine: PlayerEngine

    init(engine: PlayerEngine = DefaultPlayerEngine()) {
        self.engine = engine
        self.engine.delegate = self
    }

    func load(item: MediaItem) {
        engine.load(item: item)
    }

    func play(item: MediaItem) {
        engine.load(item: item)
        engine.play()
    }

    func pause() { engine.pause() }
    func seek(to time: TimeInterval) { engine.seek(to: time) }

    func player(_ engine: PlayerEngine, didUpdate state: PlaybackState) {
        DispatchQueue.main.async {
            self.state = state
        }
    }

    func player(_ engine: PlayerEngine, didFail error: PlayerError) {
        print("Player error: \(error)")
    }
}
#endif
