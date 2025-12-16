import Foundation
import Core
import Common

public final class DefaultPlayerEngine: PlayerEngine {
    public weak var delegate: PlayerEngineDelegate?
    private var state = PlaybackState()
    private var currentItem: MediaItem?

    public init() {}

    public func load(item: MediaItem) async throws {
        guard item.localURL != nil else {
            throw PlayerError.fileNotFound
        }
        currentItem = item
        state = PlaybackState(
            isPlaying: false,
            currentTime: 0,
            duration: item.runtime ?? 0,
            bufferedTime: 0,
            selectedAudio: item.audioTracks.first(where: { $0.isDefault }) ?? item.audioTracks.first,
            selectedSubtitle: item.subtitles.first(where: { $0.isDefault }) ?? item.subtitles.first
        )
        delegate?.playerDidUpdate(state: state)
    }

    public func play() async {
        state.isPlaying = true
        delegate?.playerDidUpdate(state: state)
    }

    public func pause() async {
        state.isPlaying = false
        delegate?.playerDidUpdate(state: state)
    }

    public func seek(to time: TimeInterval) async {
        state.currentTime = min(max(0, time), state.duration)
        delegate?.playerDidUpdate(state: state)
    }

    public func setPlaybackRate(_ rate: Float) async {
        // In a real implementation, forward the rate to AVPlayer/FFmpeg.
        print("Playback rate changed to", rate)
    }

    public func selectAudioTrack(_ track: AudioTrack) async {
        state.selectedAudio = track
        delegate?.playerDidUpdate(state: state)
    }

    public func selectSubtitle(_ subtitle: Subtitle?) async {
        state.selectedSubtitle = subtitle
        delegate?.playerDidUpdate(state: state)
    }
}
