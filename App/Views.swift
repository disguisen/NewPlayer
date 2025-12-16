import SwiftUI
import Common
import Player
import Library
#if canImport(AVKit)
import AVKit
#endif

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
    @State private var gestureHint: String?

    init(item: MediaItem) {
        _viewModel = StateObject(wrappedValue: PlayerDetailViewModel(item: item))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            #if canImport(AVKit)
            videoSurface
            #endif
            header
            metadataSection
            playbackSection
            gestureHints
            trackSelectors
            subtitleStyleControls
            controlExtras
            Spacer()
        }
        .padding()
        .navigationTitle(viewModel.item.title)
    }

#if canImport(AVKit)
    private var videoSurface: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                if let player = viewModel.avPlayer {
                    VideoPlayer(player: player)
                        .onAppear { viewModel.activateRemoteCommands() }
                } else {
                    Rectangle()
                        .fill(.gray.opacity(0.2))
                        .overlay { Text("加载播放器...") }
                }
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .center) { gestureOverlay }

            if viewModel.isPictureInPictureAvailable {
                Button {
                    viewModel.togglePictureInPicture()
                } label: {
                    Label(viewModel.isPictureInPictureActive ? "退出画中画" : "画中画", systemImage: "pip")
                        .padding(8)
                }
                .buttonStyle(.borderedProminent)
                .padding(8)
            }
        }
    }

    private var gestureOverlay: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        viewModel.jump(by: -10)
                        gestureHint = "-10s"
                    }
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        viewModel.jump(by: 10)
                        gestureHint = "+10s"
                    }
            }
            .overlay(alignment: .center) {
                if let gestureHint {
                    Text(gestureHint)
                        .font(.headline.monospacedDigit())
                        .padding(8)
                        .background(.thinMaterial, in: Capsule())
                        .transition(.opacity)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        let scale = TimeInterval(value.translation.width / proxy.size.width) * 60
                        viewModel.jump(by: scale)
                        gestureHint = String(format: "%+.0fs", scale)
                    }
            )
        }
    }
#endif

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

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("海报: \(viewModel.cacheSnapshot.poster.displayText)", systemImage: "photo")
                Label("背景: \(viewModel.cacheSnapshot.backdrop.displayText)", systemImage: "photo.fill.on.rectangle.fill")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let metadataMessage = viewModel.metadataMessage {
                Text(metadataMessage)
                    .font(.footnote)
                    .foregroundStyle(.blue)
            }

            Button {
                viewModel.refreshMetadata()
            } label: {
                if viewModel.isRefreshingMetadata {
                    ProgressView().progressViewStyle(.circular)
                } else {
                    Label("刷新元数据", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
            .tint(.blue)
            .disabled(viewModel.isRefreshingMetadata)
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

    private var gestureHints: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("手势快捷")
                .font(.headline)
            Label("左右滑动快进/快退，双击左右区域跳转10秒。", systemImage: "hand.tap")
                .font(.footnote)
                .foregroundStyle(.secondary)
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

    private var subtitleStyleControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("字幕样式")
                .font(.headline)
            HStack {
                Text("字号")
                Slider(value: Binding(
                    get: { viewModel.subtitleStyle.fontSize },
                    set: { viewModel.updateSubtitleFontSize($0) }
                ), in: 12...36, step: 1)
                Text("\(Int(viewModel.subtitleStyle.fontSize))")
                    .font(.caption.monospacedDigit())
            }
            HStack {
                Text("描边")
                Slider(value: Binding(
                    get: { viewModel.subtitleStyle.outlineWidth },
                    set: { viewModel.updateSubtitleOutline($0) }
                ), in: 0...4, step: 0.5)
                Text(String(format: "%.1f", viewModel.subtitleStyle.outlineWidth))
                    .font(.caption.monospacedDigit())
            }
            HStack {
                Text("背景透明度")
                Slider(value: Binding(
                    get: { viewModel.subtitleStyle.backgroundOpacity },
                    set: { viewModel.updateSubtitleBackground($0) }
                ), in: 0...1)
                Text(String(format: "%.0f%%", viewModel.subtitleStyle.backgroundOpacity * 100))
                    .font(.caption.monospacedDigit())
            }
            Picker("颜色", selection: Binding(
                get: { viewModel.subtitleStyle.textColorHex },
                set: { viewModel.updateSubtitleColor($0) }
            )) {
                ForEach(PlayerDetailViewModel.subtitleColorOptions, id: \.self) { hex in
                    Label(hex, systemImage: "circle.fill")
                        .foregroundStyle(Color(hex: hex))
                        .tag(hex)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var controlExtras: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("播放扩展")
                .font(.headline)
            HStack {
                Label(viewModel.remoteControlStatus, systemImage: "dot.radiowaves.left.and.right")
                Spacer()
                Button("刷新元数据缓存") {
                    viewModel.refreshMetadata()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

final class PlayerDetailViewModel: NSObject, ObservableObject {
    @Published var state: PlaybackState
    @Published var errorMessage: String?
    @Published var metadataMessage: String?
    @Published var isRefreshingMetadata = false
    @Published var cacheSnapshot: MetadataCacheSnapshot
    @Published var item: MediaItem
    @Published var subtitleStyle: SubtitleStylePreferences = .init()
    let availableRates: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
    static let subtitleColorOptions: [String] = ["#FFFFFF", "#FFB703", "#00E0FF", "#F94144"]

    private let engine: PlayerEngine
    private let metadataService: MetadataServiceProtocol
    private var engineRate: Float = 1.0

#if canImport(AVFoundation)
    var avPlayer: AVPlayer? {
        (engine as? AVPlayerBackedEngine)?.avPlayer
    }

    var isPictureInPictureAvailable: Bool {
        engine is PictureInPictureSupporting
    }

    var isPictureInPictureActive: Bool {
        (engine as? PictureInPictureSupporting)?.isPictureInPictureActive ?? false
    }
#endif

    var remoteControlStatus: String {
        if engine is RemoteCommandSupporting {
            return "远程控制中心已激活"
        }
        return "远程控制中心不可用"
    }

    init(item: MediaItem,
         engine: PlayerEngine = PlayerDetailViewModel.makeDefaultEngine(),
         metadataService: MetadataServiceProtocol = MetadataService()) {
        self.item = item
        self.engine = engine
        self.metadataService = metadataService
        self.state = PlaybackState()
        self.cacheSnapshot = MetadataCacheSnapshot(poster: metadataService.cacheStatus(for: item.posterURL), backdrop: metadataService.cacheStatus(for: item.backdropURL))
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

    private static func makeDefaultEngine() -> PlayerEngine {
#if canImport(FFmpegKit)
        return FFmpegPlayerEngine()
#else
        return DefaultPlayerEngine()
#endif
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

    func updateSubtitleFontSize(_ newValue: Double) {
        subtitleStyle.fontSize = newValue
    }

    func updateSubtitleColor(_ newValue: String) {
        subtitleStyle.textColorHex = newValue
    }

    func updateSubtitleOutline(_ newValue: Double) {
        subtitleStyle.outlineWidth = newValue
    }

    func updateSubtitleBackground(_ newValue: Double) {
        subtitleStyle.backgroundOpacity = newValue
    }

#if canImport(AVFoundation)
    func togglePictureInPicture() {
        guard let pipEngine = engine as? PictureInPictureSupporting else { return }
        Task {
            if pipEngine.isPictureInPictureActive {
                await pipEngine.stopPictureInPicture()
            } else {
                await pipEngine.startPictureInPicture()
            }
        }
    }

    func activateRemoteCommands() {
        (engine as? RemoteCommandSupporting)?.configureRemoteCommandsIfNeeded()
    }
#endif

    func refreshMetadata() {
        Task {
            await MainActor.run {
                isRefreshingMetadata = true
                metadataMessage = nil
            }

            do {
                let enriched = try await metadataService.fetchMetadata(for: item)
                await MainActor.run {
                    self.item = enriched
                    self.cacheSnapshot = MetadataCacheSnapshot(poster: metadataService.cacheStatus(for: enriched.posterURL), backdrop: metadataService.cacheStatus(for: enriched.backdropURL))
                    self.metadataMessage = "已刷新元数据"
                }
            } catch {
                await MainActor.run {
                    self.metadataMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                isRefreshingMetadata = false
            }
        }
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

struct MetadataCacheSnapshot: Equatable {
    var poster: MetadataCacheStatus
    var backdrop: MetadataCacheStatus
}

private extension MetadataCacheStatus {
    var displayText: String {
        switch self {
        case .cached(_): return "已缓存"
        case .missing: return "未缓存"
        }
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 8:
            (a, r, g, b) = (int >> 24, (int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        default:
            (a, r, g, b) = (255, (int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
