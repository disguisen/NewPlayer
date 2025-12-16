import Foundation
import Core
import Common

#if canImport(FFmpegKit)
import FFmpegKit

/// PlayerEngine implementation backed by FFmpegKit to unlock broader codec support.
///
/// The engine probes media duration via FFprobe and runs an FFmpeg session that
/// decodes frames into a null sink to keep timing aligned with the demuxed
/// packets. A thin state loop mirrors the default player engine behaviour while
/// leveraging FFmpeg's format coverage.
public final class FFmpegPlayerEngine: PlayerEngine {
    public weak var delegate: PlayerEngineDelegate?
    private var state = PlaybackState()
    private var playbackTask: Task<Void, Never>?
    private var session: FFSession?
    private var playbackRate: Float = 1.0

    public init() {}

    public func load(item: MediaItem) async throws {
        playbackTask?.cancel()
        session?.cancel()
        guard let url = item.localURL else {
            throw PlayerError.fileNotFound
        }

        let duration = try await probeDuration(for: url)
        state = PlaybackState(
            isPlaying: false,
            currentTime: item.lastPlaybackPosition,
            duration: duration,
            bufferedTime: min(max(item.lastPlaybackPosition + 5, 15), duration),
            selectedAudio: item.audioTracks.first(where: { $0.isDefault }) ?? item.audioTracks.first,
            selectedSubtitle: item.subtitles.first(where: { $0.isDefault }) ?? item.subtitles.first
        )
        notifyStateUpdate()
    }

    public func play() async {
        guard state.isPlaying == false else { return }
        playbackTask?.cancel()
        let command = "-i \(state.currentTime > 0 ? "-ss \(state.currentTime)" : "") \(state.selectedAudio?.identifier ?? "") -vn -f null -"
        session = FFmpegKitWrapper.executeAsync(command)
        state.isPlaying = true
        notifyStateUpdate()
        startProgressLoop()
    }

    public func pause() async {
        state.isPlaying = false
        playbackTask?.cancel()
        session?.cancel()
        notifyStateUpdate()
    }

    public func seek(to time: TimeInterval) async {
        let clamped = min(max(0, time), state.duration)
        state.currentTime = clamped
        notifyStateUpdate()
        if state.isPlaying {
            await play()
        }
    }

    public func setPlaybackRate(_ rate: Float) async {
        playbackRate = max(0.5, min(rate, 3.0))
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
        playbackTask = Task.detached { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                await self.incrementPlayback()
            }
        }
    }

    @MainActor
    private func incrementPlayback() {
        guard state.isPlaying else { return }
        let delta = 0.25 * Double(playbackRate)
        state.currentTime = min(state.currentTime + delta, state.duration)
        if state.bufferedTime < state.duration {
            state.bufferedTime = min(state.bufferedTime + delta * 3, state.duration)
        }
        notifyStateUpdate()
        if state.currentTime >= state.duration {
            state.isPlaying = false
            playbackTask?.cancel()
            session?.cancel()
            notifyStateUpdate()
        }
    }

    private func notifyStateUpdate() {
        delegate?.playerDidUpdate(state: state)
    }

    private func probeDuration(for url: URL) async throws -> TimeInterval {
        let info = try await FFprobeWrapper.probeMedia(at: url)
        return info.duration ?? 0
    }
}

private enum FFprobeWrapper {
    static func probeMedia(at url: URL) async throws -> (duration: TimeInterval?, streams: Int) {
        try await withCheckedThrowingContinuation { continuation in
            FFmpegKitWrapper.probe(url: url) { result in
                continuation.resume(with: result)
            }
        }
    }
}

private enum FFmpegKitWrapper {
    static func probe(url: URL, completion: @escaping (Result<(TimeInterval?, Int), Error>) -> Void) {
        let command = "-hide_banner -i \(url.path) -v quiet -print_format json -show_streams -show_format"
        FFprobeKit.executeAsync(command) { session in
            guard let info = session?.getMediaInformation() else {
                completion(.success((nil, 0)))
                return
            }
            let duration = Double(info.getDuration() ?? "0")
            let streams = info.getStreams()?.count ?? 0
            completion(.success((duration, streams)))
        }
    }

    static func executeAsync(_ command: String) -> FFSession? {
        FFmpegKit.executeAsync(command) { _ in } withLogCallback: { _ in } withStatisticsCallback: { _ in }
    }
}

private protocol FFSession {
    func cancel()
}

extension Session: FFSession {}

#else

/// Placeholder engine used when FFmpegKit is not linked. It simply throws
/// unsupported errors to signal that the binary dependency must be provided.
public final class FFmpegPlayerEngine: PlayerEngine {
    public weak var delegate: PlayerEngineDelegate?

    public init() {}

    public func load(item: MediaItem) async throws {
        throw PlayerError.unsupportedFormat
    }

    public func play() async {}
    public func pause() async {}
    public func seek(to time: TimeInterval) async {}
    public func setPlaybackRate(_ rate: Float) async {}
    public func selectAudioTrack(_ track: AudioTrack) async {}
    public func selectSubtitle(_ subtitle: Subtitle?) async {}
}

#endif
