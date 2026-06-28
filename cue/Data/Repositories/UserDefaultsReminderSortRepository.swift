//
//  UserDefaultsReminderSortRepository.swift
//  cue / Data
//

import Foundation

/// `ReminderSortRepository`의 UserDefaults 구현 — `[scope: ReminderSortSettings]`를
/// 한 키에 JSON으로 저장한다(Memo 저장 패턴과 동일). 로컬 전용, iCloud 동기화 없음.
struct UserDefaultsReminderSortRepository: ReminderSortRepository, @unchecked Sendable {
    private static let storageKey = "cue.reminderSort.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func fetch(scope: String) async -> ReminderSortSettings {
        load()[scope] ?? .default
    }

    func save(_ settings: ReminderSortSettings, scope: String) async {
        var all = load()
        all[scope] = settings
        guard let data = try? JSONEncoder().encode(all) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    /// 전체 스코프 맵을 읽는다. 없거나 깨졌으면 빈 맵.
    private func load() -> [String: ReminderSortSettings] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let map = try? JSONDecoder().decode([String: ReminderSortSettings].self, from: data)
        else { return [:] }
        return map
    }
}
