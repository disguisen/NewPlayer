import Foundation
import Common
import Core

public final class FFmpegPlayerEngine: PlayerEngine {
    public weak var delegate: PlayerEngineDelegate?
    private var state = PlaybackState(isPlaying: false, currentTime: 0, duration: 0, buffered: 0, rate: 1)

    public init() {}

    public func load(item: MediaItem) {
        state.duration = item.duration ?? 0
        delegate?.player(self, didUpdate: state)
    }

    public func play() {
        state.isPlaying = true
        delegate?.player(self, didUpdate: state)
    }

    public func pause() {
        state.isPlaying = false
        delegate?.player(self, didUpdate: state)
    }

    public func seek(to time: TimeInterval) {
        state.currentTime = time
        delegate?.player(self, didUpdate: state)
    }

    public func setRate(_ rate: Float) {
        state.rate = rate
        delegate?.player(self, didUpdate: state)
    }

    public func selectAudio(languageCode: String) {}

    public func selectSubtitle(languageCode: String?) {}
}
