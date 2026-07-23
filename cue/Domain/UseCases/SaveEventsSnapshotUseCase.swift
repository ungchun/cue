//
//  SaveEventsSnapshotUseCase.swift
//  cue / Domain
//

/// fetch 성공 결과를 일정 스냅샷으로 저장 — 다음 실행의 첫 페인트 재료.
struct SaveEventsSnapshotUseCase: Sendable {
    private let repository: any SnapshotCacheRepository

    init(repository: any SnapshotCacheRepository) {
        self.repository = repository
    }

    func callAsFunction(_ snapshot: EventsSnapshot) async {
        await repository.saveEventsSnapshot(snapshot)
    }
}
