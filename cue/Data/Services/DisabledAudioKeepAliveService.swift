//
//  DisabledAudioKeepAliveService.swift
//  cue / Data
//

import Foundation

/// `BackgroundAudioKeeping`의 no-op 구현 — 테스트·Preview용. 오디오 세션을 건드리지 않는다.
struct DisabledAudioKeepAliveService: BackgroundAudioKeeping {
    func start() {}
    func stop() {}
}
