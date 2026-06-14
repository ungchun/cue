//
//  AVAudioKeepAliveService.swift
//  cue / Data
//

import AVFoundation

/// `BackgroundAudioKeeping`의 시스템 구현 — `AVAudioEngine`으로 **무음** 버퍼를 루프 재생해
/// 앱을 백그라운드에서 깨어 있게 유지한다.
///
/// `.mixWithOthers`로 사용자의 다른 오디오(음악 등)를 끊지 않고 공존한다. 무음 데이터라
/// 들리지 않지만 오디오 세션이 활성이라 OS가 앱을 재우지 않는다 — 그동안 타이머가 돌아
/// 단계 전환·LA 갱신이 백그라운드/잠금에서도 작동.
///
/// 추후 집중 사운드로 교체할 땐 `silentBuffer`를 실제 오디오 버퍼/파일 재생으로 바꾸고
/// `.mixWithOthers`를 떼면 된다 — `start`/`stop` 인터페이스는 그대로.
///
/// 전화 등 인터럽션으로 세션이 끊기면 `.ended` 시점에 다시 활성화해 keep-alive를 복구한다.
@MainActor
final class AVAudioKeepAliveService: BackgroundAudioKeeping {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
    private var isRunning = false
    private var interruptionObserver: NSObjectProtocol?

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func start() {
        guard !isRunning else { return }
        observeInterruptions()
        activate()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
        player.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - 내부

    /// 오디오 세션 활성 + 무음 루프 재생. 시작·인터럽션 복구에서 공유.
    private func activate() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            if !engine.isRunning { try engine.start() }
            player.scheduleBuffer(silentBuffer(), at: nil, options: .loops)
            player.play()
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    /// 1초 길이의 무음(zeros) PCM 버퍼. `.loops`로 무한 반복 — 에셋 파일 없이 코드로 생성.
    private func silentBuffer() -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames // 채널 데이터는 0으로 초기화 = 무음
        return buffer
    }

    private func observeInterruptions() {
        guard interruptionObserver == nil else { return }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            // note는 Sendable이 아니므로 MainActor로 넘기기 전에 Bool로 추출.
            let ended = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .ended
            guard ended else { return }
            // 인터럽션 종료 → keep-alive 복구.
            Task { @MainActor in self?.activate() }
        }
    }
}
