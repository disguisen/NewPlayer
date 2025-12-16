import Foundation
import Common

public protocol PlayerEngine: AnyObject {
    var delegate: PlayerEngineDelegate? { get set }

    func load(item: MediaItem) async throws
    func play() async
    func pause() async
    func seek(to time: TimeInterval) async
    func setPlaybackRate(_ rate: Float) async
    func selectAudioTrack(_ track: AudioTrack) async
    func selectSubtitle(_ subtitle: Subtitle?) async
}

public protocol PlayerEngineDelegate: AnyObject {
    func playerDidUpdate(state: PlaybackState)
    func playerDidFail(_ error: PlayerError)
}

#if canImport(AVFoundation)
import AVFoundation

public protocol AVPlayerBackedEngine: PlayerEngine {
    var avPlayer: AVPlayer? { get }
}
#else
public protocol AVPlayerBackedEngine: PlayerEngine {}
#endif

public protocol PictureInPictureSupporting: PlayerEngine {
    var isPictureInPictureActive: Bool { get }
    func startPictureInPicture() async
    func stopPictureInPicture() async
}

public protocol RemoteCommandSupporting: PlayerEngine {
    func configureRemoteCommandsIfNeeded()
    func teardownRemoteCommands()
}

public struct PlaybackState: Equatable {
    public var isPlaying: Bool
    public var currentTime: TimeInterval
    public var duration: TimeInterval
    public var bufferedTime: TimeInterval
    public var selectedAudio: AudioTrack?
    public var selectedSubtitle: Subtitle?

    public init(
        isPlaying: Bool = false,
        currentTime: TimeInterval = 0,
        duration: TimeInterval = 0,
        bufferedTime: TimeInterval = 0,
        selectedAudio: AudioTrack? = nil,
        selectedSubtitle: Subtitle? = nil
    ) {
        self.isPlaying = isPlaying
        self.currentTime = currentTime
        self.duration = duration
        self.bufferedTime = bufferedTime
        self.selectedAudio = selectedAudio
        self.selectedSubtitle = selectedSubtitle
    }
}
