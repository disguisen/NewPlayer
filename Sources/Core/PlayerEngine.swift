import Foundation
import Common

public protocol PlayerEngineDelegate: AnyObject {
    func player(_ engine: PlayerEngine, didUpdate state: PlaybackState)
    func player(_ engine: PlayerEngine, didFail error: PlayerError)
}

public protocol PlayerEngine: AnyObject {
    var delegate: PlayerEngineDelegate? { get set }
    func load(item: MediaItem)
    func play()
    func pause()
    func seek(to time: TimeInterval)
    func setRate(_ rate: Float)
    func selectAudio(languageCode: String)
    func selectSubtitle(languageCode: String?)
}
