import Foundation
import Common
import Core

#if canImport(AVFoundation)
import AVFoundation
#endif

public final class DefaultPlayerEngine: PlayerEngine {
    public weak var delegate: PlayerEngineDelegate?
    private var currentItem: MediaItem?
    private var state = PlaybackState(isPlaying: false, currentTime: 0, duration: 0, buffered: 0, rate: 1)

    #if canImport(AVFoundation)
    private var player: AVPlayer?
    #endif

    public init() {}

    public func load(item: MediaItem) {
        currentItem = item
        #if canImport(AVFoundation)
        if let url = item.url {
            player = AVPlayer(url: url)
        }
        #endif
        state.duration = item.duration ?? 0
        notifyUpdate()
    }

    public func play() {
        #if canImport(AVFoundation)
        player?.play()
        #endif
        state.isPlaying = true
        notifyUpdate()
    }

    public func pause() {
        #if canImport(AVFoundation)
        player?.pause()
        #endif
        state.isPlaying = false
        notifyUpdate()
    }

    public func seek(to time: TimeInterval) {
        state.currentTime = time
        #if canImport(AVFoundation)
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
        #endif
        notifyUpdate()
    }

    public func setRate(_ rate: Float) {
        state.rate = rate
        #if canImport(AVFoundation)
        player?.rate = rate
        #endif
        notifyUpdate()
    }

    public func selectAudio(languageCode: String) {
        // Placeholder: map to AVPlayer selection when available
    }

    public func selectSubtitle(languageCode: String?) {
        // Placeholder
    }

    private func notifyUpdate() {
        delegate?.player(self, didUpdate: state)
    }
}
