import SwiftUI
import Common
import Player

struct HomeView: View {
    let items: [MediaItem]

    var body: some View {
        NavigationStack {
            List(items.prefix(5)) { item in
                NavigationLink(destination: PlayerDetailView(item: item)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)
                        if let overview = item.overview {
                            Text(overview)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .navigationTitle("继续观看")
        }
    }
}

struct LibraryView: View {
    let items: [MediaItem]

    var body: some View {
        NavigationStack {
            List(items) { item in
                NavigationLink(destination: PlayerDetailView(item: item)) {
                    VStack(alignment: .leading) {
                        Text(item.title)
                        Text(item.type.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("媒体库")
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("播放") {
                    Toggle("硬件解码", isOn: .constant(true))
                    Toggle("后台播放", isOn: .constant(true))
                }
                Section("字幕") {
                    Toggle("自动匹配字幕", isOn: .constant(true))
                    Stepper("字幕大小", value: .constant(16), in: 12...30)
                }
            }
            .navigationTitle("设置")
        }
    }
}

struct PlayerDetailView: View {
    @StateObject private var viewModel: PlayerDetailViewModel

    init(item: MediaItem) {
        _viewModel = StateObject(wrappedValue: PlayerDetailViewModel(item: item))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            playbackSection
            trackSelectors
            Spacer()
        }
        .padding()
        .navigationTitle(viewModel.item.title)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.item.title)
                .font(.title)
            if let overview = viewModel.item.overview {
                Text(overview)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var playbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red)
            }
            ProgressView(value: viewModel.bufferedFraction) {
                Text("缓冲")
            }
            .progressViewStyle(.linear)

            HStack {
                Text(viewModel.elapsedText)
                    .font(.caption.monospacedDigit())
                Slider(value: Binding(
                    get: { viewModel.state.currentTime },
                    set: { viewModel.seek(to: $0) }
                ), in: 0...max(1, viewModel.state.duration))
                Text(viewModel.remainingText)
                    .font(.caption.monospacedDigit())
            }

            HStack(spacing: 24) {
                Button(viewModel.state.isPlaying ? "暂停" : "播放") {
                    viewModel.togglePlayPause()
                }
                Button("-15s") { viewModel.jump(by: -15) }
                Button("+30s") { viewModel.jump(by: 30) }
                Menu("倍速 \(String(format: "%.2gx", viewModel.playbackRate))") {
                    ForEach(viewModel.availableRates, id: \.self) { rate in
                        Button(String(format: "%.2gx", rate)) {
                            viewModel.setRate(rate)
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var trackSelectors: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.item.audioTracks.isEmpty {
                Text("音轨")
                    .font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(viewModel.item.audioTracks) { track in
                            Button(track.name) {
                                viewModel.selectAudio(track)
                            }
                            .buttonStyle(.bordered)
                            .tint(track.id == viewModel.state.selectedAudio?.id ? .blue : .gray)
                        }
                    }
                }
            }
            if !viewModel.item.subtitles.isEmpty {
                Text("字幕")
                    .font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Button("关闭字幕") {
                            viewModel.selectSubtitle(nil)
                        }
                        .buttonStyle(.bordered)
                        .tint(viewModel.state.selectedSubtitle == nil ? .blue : .gray)
                        ForEach(viewModel.item.subtitles) { subtitle in
                            Button(subtitle.name) {
                                viewModel.selectSubtitle(subtitle)
                            }
                            .buttonStyle(.bordered)
                            .tint(subtitle.id == viewModel.state.selectedSubtitle?.id ? .blue : .gray)
                        }
                    }
                }
            }
        }
    }
}

final class PlayerDetailViewModel: NSObject, ObservableObject {
    @Published var state: PlaybackState
    @Published var errorMessage: String?
    let item: MediaItem
    let availableRates: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    private let engine: PlayerEngine
    private var engineRate: Float = 1.0

    init(item: MediaItem, engine: PlayerEngine = DefaultPlayerEngine()) {
        self.item = item
        self.engine = engine
        self.state = PlaybackState()
        super.init()
        self.engine.delegate = self
        Task { await load() }
    }

    var elapsedText: String {
        format(time: state.currentTime)
    }

    var remainingText: String {
        let remaining = max(state.duration - state.currentTime, 0)
        return "-" + format(time: remaining)
    }

    var bufferedFraction: Double {
        guard state.duration > 0 else { return 0 }
        return state.bufferedTime / state.duration
    }

    var playbackRate: Float {
        engineRate
    }

    @MainActor
    private func load() async {
        do {
            try await engine.load(item: item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePlayPause() {
        Task {
            if state.isPlaying {
                await engine.pause()
            } else {
                await engine.play()
            }
        }
    }

    func jump(by delta: TimeInterval) {
        seek(to: state.currentTime + delta)
    }

    func seek(to time: TimeInterval) {
        Task { await engine.seek(to: time) }
    }

    func setRate(_ rate: Float) {
        engineRate = rate
        Task { await engine.setPlaybackRate(rate) }
    }

    func selectAudio(_ track: AudioTrack) {
        Task { await engine.selectAudioTrack(track) }
    }

    func selectSubtitle(_ subtitle: Subtitle?) {
        Task { await engine.selectSubtitle(subtitle) }
    }

    private func format(time: TimeInterval) -> String {
        guard !time.isNaN && !time.isInfinite else { return "--:--" }
        let seconds = Int(time)
        let minutes = seconds / 60
        let hours = minutes / 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes % 60, seconds % 60)
        } else {
            return String(format: "%02d:%02d", minutes % 60, seconds % 60)
        }
    }
}

extension PlayerDetailViewModel: PlayerEngineDelegate {
    func playerDidUpdate(state: PlaybackState) {
        Task { @MainActor in
            self.state = state
        }
    }

    func playerDidFail(_ error: PlayerError) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
        }
    }
}
