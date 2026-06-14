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
            // `.mixWithOthers`를 쓰면 iOS가 '보조 오디오'로 보고 백그라운드 실행 권한을 안 줘
            // keep-alive가 안 된다. 주 오디오(.playback, 옵션 없음)여야 앱이 깨어 있는다.
            // 비용: 세션 시작 시 사용자의 다른 오디오가 멈춘다(무음 keep-alive의 불가피한 한계).
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            if !engine.isRunning { try engine.start() }
            player.scheduleBuffer(keepAliveBuffer(), at: nil, options: .loops)
            player.play()
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    /// 1초 길이의 **거의 안 들리는** keep-alive PCM 버퍼. `.loops`로 무한 반복 — 에셋 파일
    /// 없이 코드로 생성. 완전 무음(zeros)은 일부 환경에서 iOS가 '재생 중'으로 인식 못 해
    /// 백그라운드 유지가 안 될 수 있어, 초저진폭(0.002 ≈ -54dB) 저주파 사인으로 채워
    /// 폰 스피커에선 사실상 무음이되 오디오 세션은 확실히 active로 인식되게 한다.
    private func keepAliveBuffer() -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        guard let channels = buffer.floatChannelData else { return buffer }
        // ⚠️ 진단용 — 들리는 톤(440Hz, 0.1). 잠금 후에도 소리가 계속 나면 keep-alive가
        // 백그라운드에서 살아 있다는 증거. 확인 후 무음(0.002)으로 되돌리거나 집중 사운드로 교체.
        let amplitude: Float = 0.1
        let sampleRate = Float(format.sampleRate)
        for frame in 0..<Int(frames) {
            let value = amplitude * sin(2 * .pi * 440 * Float(frame) / sampleRate)
            for ch in 0..<Int(format.channelCount) {
                channels[ch][frame] = value
            }
        }
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
