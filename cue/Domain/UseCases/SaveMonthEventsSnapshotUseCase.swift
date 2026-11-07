//
//  SaveMonthEventsSnapshotUseCase.swift
//  cue / Domain
//

/// 달별 조회 결과를 월 캘린더 스냅샷으로 저장 — 다음 실행의 첫 페인트 재료.
struct SaveMonthEventsSnapshotUseCase: Sendable {
    private let repository: any SnapshotCacheRepository

    init(repository: any SnapshotCacheRepository) {
        self.repository = repository
    }

    func callAsFunction(_ snapshot: MonthEventsSnapshot) async {
        await repository.saveMonthEventsSnapshot(snapshot)
    }
}
