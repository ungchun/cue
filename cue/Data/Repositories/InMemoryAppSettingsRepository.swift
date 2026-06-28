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

    func fetch() -> AppSettings { storage }

    func save(_ settings: AppSettings) { storage = settings }
}
