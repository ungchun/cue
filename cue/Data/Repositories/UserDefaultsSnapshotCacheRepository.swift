//
//  UserDefaultsSnapshotCacheRepository.swift
//  cue / Data
//

import Foundation

/// `SnapshotCacheRepository`의 UserDefaults 구현 — 스냅샷을 종류별 키에 JSON으로 저장한다
/// (`UserDefaultsReminderSortRepository`와 동일 패턴). 로컬 전용, iCloud 동기화 없음.
/// 깨진 데이터는 nil로 취급 — 캐시일 뿐이므로 복구 시도 없이 스피너 경로로 넘긴다.
struct UserDefaultsSnapshotCacheRepository: SnapshotCacheRepository, @unchecked Sendable {
    private static let remindersKey = "cue.snapshot.reminders.v1"
    private static let eventsKey = "cue.snapshot.events.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadRemindersSnapshot() async -> RemindersSnapshot? {
        load(RemindersSnapshot.self, key: Self.remindersKey)
    }

    func saveRemindersSnapshot(_ snapshot: RemindersSnapshot) async {
        save(snapshot, key: Self.remindersKey)
    }

    func loadEventsSnapshot() async -> EventsSnapshot? {
        load(EventsSnapshot.self, key: Self.eventsKey)
    }

    func saveEventsSnapshot(_ snapshot: EventsSnapshot) async {
        save(snapshot, key: Self.eventsKey)
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
