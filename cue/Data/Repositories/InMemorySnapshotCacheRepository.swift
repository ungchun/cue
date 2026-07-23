//
//  InMemorySnapshotCacheRepository.swift
//  cue / Data
//

/// `SnapshotCacheRepository`의 인메모리 구현 — 프리뷰·테스트용.
/// 테스트가 저장 결과를 들여다볼 수 있게 actor 상태를 그대로 노출한다.
actor InMemorySnapshotCacheRepository: SnapshotCacheRepository {
    private(set) var remindersSnapshot: RemindersSnapshot?
    private(set) var eventsSnapshot: EventsSnapshot?

    init(
        remindersSnapshot: RemindersSnapshot? = nil,
        eventsSnapshot: EventsSnapshot? = nil
    ) {
        self.remindersSnapshot = remindersSnapshot
        self.eventsSnapshot = eventsSnapshot
    }

    func loadRemindersSnapshot() async -> RemindersSnapshot? { remindersSnapshot }

    func saveRemindersSnapshot(_ snapshot: RemindersSnapshot) async {
        remindersSnapshot = snapshot
    }

    func loadEventsSnapshot() async -> EventsSnapshot? { eventsSnapshot }

    func saveEventsSnapshot(_ snapshot: EventsSnapshot) async {
        eventsSnapshot = snapshot
    }
}
