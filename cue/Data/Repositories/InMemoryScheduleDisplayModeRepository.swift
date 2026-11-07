//
//  InMemoryScheduleDisplayModeRepository.swift
//  cue / Data
//

import Foundation

/// 프리뷰·테스트용 인메모리 구현. 프로토콜이 동기라 `actor`를 못 쓰므로
/// 락으로 보호하는 `final class`로 `Sendable`을 만족한다.
final class InMemoryScheduleDisplayModeRepository: ScheduleDisplayModeRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var mode: ScheduleDisplayMode?

    init(mode: ScheduleDisplayMode? = nil) {
        self.mode = mode
    }

    func fetch() -> ScheduleDisplayMode? {
        lock.withLock { mode }
    }

    func save(_ mode: ScheduleDisplayMode) {
        lock.withLock { self.mode = mode }
    }
}
