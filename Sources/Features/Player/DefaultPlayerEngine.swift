import Foundation
import Core
import Common

public final class DefaultPlayerEngine: PlayerEngine {
    public weak var delegate: PlayerEngineDelegate?
    private var state = PlaybackState()
    private var currentItem: MediaItem?
    private var playbackTask: Task<Void, Never>?
    private var playbackRate: Float = 1.0

    public init() {}

    public func load(item: MediaItem) async throws {
        playbackTask?.cancel()
        guard item.localURL != nil else {
            throw PlayerError.fileNotFound
        }
        currentItem = item
        let duration = item.runtime ?? 120
        state = PlaybackState(
            isPlaying: false,
            currentTime: item.lastPlaybackPosition,
            duration: duration,
            bufferedTime: min(max(item.lastPlaybackPosition + 10, 30), duration),
            selectedAudio: item.audioTracks.first(where: { $0.isDefault }) ?? item.audioTracks.first,
            selectedSubtitle: item.subtitles.first(where: { $0.isDefault }) ?? item.subtitles.first
        )
        notifyStateUpdate()
    }

    public func play() async {
        guard state.isPlaying == false else { return }
        state.isPlaying = true
        notifyStateUpdate()
        startProgressLoop()
    }

    public func pause() async {
        state.isPlaying = false
        playbackTask?.cancel()
        notifyStateUpdate()
    }

    public func seek(to time: TimeInterval) async {
        let clamped = min(max(0, time), state.duration)
        state.currentTime = clamped
        notifyStateUpdate()
    }

    public func setPlaybackRate(_ rate: Float) async {
        playbackRate = max(0.5, min(rate, 3.0))
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

    private func startProgressLoop() {
        playbackTask?.cancel()
        playbackTask = Task.detached { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000)
                await self.incrementPlayback()
            }
        }
    }

    @MainActor
    private func incrementPlayback() {
        guard state.isPlaying else { return }
        let delta = 0.3 * Double(playbackRate)
        state.currentTime = min(state.currentTime + delta, state.duration)
        if state.bufferedTime < state.duration {
            state.bufferedTime = min(state.bufferedTime + delta * 2, state.duration)
        }
        notifyStateUpdate()
        if state.currentTime >= state.duration {
            state.isPlaying = false
            playbackTask?.cancel()
            notifyStateUpdate()
        }
    }

    private func notifyStateUpdate() {
        delegate?.playerDidUpdate(state: state)
    }
}
