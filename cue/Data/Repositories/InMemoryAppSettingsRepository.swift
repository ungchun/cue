//
//  InMemoryAppSettingsRepository.swift
//  cue / Data
//

import Foundation

/// 프리뷰·테스트용 인메모리 구현. `actor`로 격리해 `Sendable`을 만족한다.
actor InMemoryAppSettingsRepository: AppSettingsRepository {
    private var storage: AppSettings

    init(storage: AppSettings = .default) {
        self.storage = storage
    }

    /// 저장 호출 횟수 — 테스트가 "불필요한 write 없음"을 검증할 때 읽는다.
    private(set) var saveCount = 0

    func fetch() -> AppSettings { storage }

    func save(_ settings: AppSettings) {
        storage = settings
        saveCount += 1
    }
}
