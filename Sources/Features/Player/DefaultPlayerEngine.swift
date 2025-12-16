#if canImport(AVFoundation)
import Foundation
import AVFoundation
import Core
import Common

/// Default PlayerEngine backed by AVPlayer. It performs real playback,
/// periodically emits position/buffer updates, and mirrors audio/subtitle
/// selections to media selection groups. When AVFoundation is unavailable,
/// the typealiases at the bottom of the file provide fallbacks.
public final class DefaultPlayerEngine: NSObject, PlayerEngine {
    public weak var delegate: PlayerEngineDelegate?

    private var state = PlaybackState()
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var bufferObserver: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var playbackRate: Float = 1.0
    private var currentItem: MediaItem?

    public override init() {
        super.init()
    }

    deinit {
        cleanupPlayer()
    }

    public func load(item: MediaItem) async throws {
        guard let url = item.localURL else {
            throw PlayerError.fileNotFound
        }

        await MainActor.run {
            self.cleanupPlayer()
            self.currentItem = item
            let asset = AVURLAsset(url: url)
            let playerItem = AVPlayerItem(asset: asset)
            self.playerItem = playerItem
            let player = AVPlayer(playerItem: playerItem)
            player.actionAtItemEnd = .pause
            self.player = player

            self.observePlayerItem()
            self.observePlaybackTime()
            self.observePlaybackEnd()

            let initialDuration = item.runtime ?? CMTimeGetSeconds(playerItem.asset.duration)
            self.state = PlaybackState(
                isPlaying: false,
                currentTime: item.lastPlaybackPosition,
                duration: initialDuration.isFinite ? initialDuration : 0,
                bufferedTime: item.lastPlaybackPosition,
                selectedAudio: item.audioTracks.first(where: { $0.isDefault }) ?? item.audioTracks.first,
                selectedSubtitle: item.subtitles.first(where: { $0.isDefault }) ?? item.subtitles.first
            )
            self.applyMediaSelections()
            self.notifyStateUpdate()
        }
    }

    public func play() async {
        await MainActor.run {
            guard state.isPlaying == false else { return }
            state.isPlaying = true
            player?.play()
            player?.rate = playbackRate
            notifyStateUpdate()
        }
    }

    public func pause() async {
        await MainActor.run {
            state.isPlaying = false
            player?.pause()
            notifyStateUpdate()
        }
    }

    public func seek(to time: TimeInterval) async {
        await MainActor.run {
            guard let player else { return }
            let clamped = min(max(0, time), state.duration)
            let target = CMTime(seconds: clamped, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
            state.currentTime = clamped
            notifyStateUpdate()
        }
    }

    public func setPlaybackRate(_ rate: Float) async {
        await MainActor.run {
            playbackRate = max(0.5, min(rate, 3.0))
            if state.isPlaying {
                player?.rate = playbackRate
            }
            notifyStateUpdate()
        }
    }

    public func selectAudioTrack(_ track: AudioTrack) async {
        await MainActor.run {
            state.selectedAudio = track
            applyMediaSelections()
            notifyStateUpdate()
        }
    }

    public func selectSubtitle(_ subtitle: Subtitle?) async {
        await MainActor.run {
            state.selectedSubtitle = subtitle
            applyMediaSelections()
            notifyStateUpdate()
        }
    }

    // MARK: - Observing

    @MainActor
    private func observePlayerItem() {
        guard let item = playerItem else { return }

        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] playerItem, _ in
            guard let self else { return }
            switch playerItem.status {
            case .readyToPlay:
                let duration = CMTimeGetSeconds(playerItem.duration)
                if duration.isFinite {
                    state.duration = duration
                }
                updateBufferedTime()
                notifyStateUpdate()
            case .failed:
                delegate?.playerDidFail(playerItem.error ?? PlayerError.decodeFailed)
            default:
                break
            }
        }

        bufferObserver = item.observe(\.loadedTimeRanges, options: [.initial, .new]) { [weak self] _, _ in
            guard let self else { return }
            updateBufferedTime()
        }
    }

    @MainActor
    private func observePlaybackTime() {
        guard let player else { return }
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            state.currentTime = CMTimeGetSeconds(time)
            if state.isPlaying {
                notifyStateUpdate()
            }
        }
    }

    @MainActor
    private func observePlaybackEnd() {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            state.isPlaying = false
            notifyStateUpdate()
        }
    }

    // MARK: - Helpers

    @MainActor
    private func updateBufferedTime() {
        guard let ranges = playerItem?.loadedTimeRanges.compactMap({ $0.timeRangeValue }) else { return }
        let buffered = ranges.map { CMTimeGetSeconds($0.start + $0.duration) }.max() ?? state.bufferedTime
        if buffered.isFinite {
            state.bufferedTime = min(buffered, state.duration)
            notifyStateUpdate()
        }
    }

    @MainActor
    private func applyMediaSelections() {
        guard let item = playerItem else { return }
        if let audioGroup = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
            let option = audioGroup.options.first { option in
                option.extendedLanguageTag == state.selectedAudio?.languageCode ||
                option.locale?.languageCode?.identifier == state.selectedAudio?.languageCode
            }
            if let option {
                item.select(option, in: audioGroup)
            }
        }

        if let subtitle = state.selectedSubtitle,
           let legible = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            let option = legible.options.first { option in
                option.extendedLanguageTag == subtitle.languageCode ||
                option.locale?.languageCode?.identifier == subtitle.languageCode
            }
            if let option {
                item.select(option, in: legible)
            }
        } else if let legible = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            item.select(nil, in: legible)
        }
    }

    @MainActor
    private func cleanupPlayer() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        statusObserver?.invalidate()
        statusObserver = nil
        bufferObserver?.invalidate()
        bufferObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        player?.pause()
        player = nil
        playerItem = nil
        state = PlaybackState()
    }

    @MainActor
    private func notifyStateUpdate() {
        delegate?.playerDidUpdate(state: state)
    }
}

#elseif canImport(FFmpegKit)
import Foundation
import Core
import Common

/// When AVFoundation is unavailable (e.g., non-Apple platforms) but FFmpegKit is
/// provided, reuse the FFmpeg-backed engine to keep real playback available.
public typealias DefaultPlayerEngine = FFmpegPlayerEngine

#else
import Foundation
import Core
import Common

/// Fallback stub used when neither AVFoundation nor FFmpegKit is available.
/// It keeps the rest of the app building while signalling missing playback
/// capabilities.
public final class DefaultPlayerEngine: PlayerEngine {
    public weak var delegate: PlayerEngineDelegate?
    private var state = PlaybackState()

    public init() {}

    public func load(item: MediaItem) async throws {
        guard item.localURL != nil else { throw PlayerError.fileNotFound }
        state = PlaybackState(
            isPlaying: false,
            currentTime: item.lastPlaybackPosition,
            duration: item.runtime ?? 0,
            bufferedTime: item.lastPlaybackPosition,
            selectedAudio: item.audioTracks.first,
            selectedSubtitle: item.subtitles.first
        )
        notifyStateUpdate()
    }

    public func play() async {
        state.isPlaying = true
        notifyStateUpdate()
    }

    public func pause() async {
        state.isPlaying = false
        notifyStateUpdate()
    }

    public func seek(to time: TimeInterval) async {
        state.currentTime = min(max(0, time), state.duration)
        notifyStateUpdate()
    }

    public func setPlaybackRate(_ rate: Float) async {
        notifyStateUpdate()
    }

    public func selectAudioTrack(_ track: AudioTrack) async {
        state.selectedAudio = track
        notifyStateUpdate()
    }

    public func selectSubtitle(_ subtitle: Subtitle?) async {
        state.selectedSubtitle = subtitle
        notifyStateUpdate()
    }

    private func notifyStateUpdate() {
        delegate?.playerDidUpdate(state: state)
    }
}

#endif
