//
//  InMemoryReminderSortRepository.swift
//  cue / Data
//

import Foundation

/// 프리뷰·테스트용 인메모리 구현. `actor`로 격리해 `Sendable`을 만족한다.
actor InMemoryReminderSortRepository: ReminderSortRepository {
    private var storage: [String: ReminderSortSettings]

    init(storage: [String: ReminderSortSettings] = [:]) {
        self.storage = storage
    }

    func fetch(scope: String) -> ReminderSortSettings {
        storage[scope] ?? .default
    }

    func save(_ settings: ReminderSortSettings, scope: String) {
        storage[scope] = settings
    }
}
