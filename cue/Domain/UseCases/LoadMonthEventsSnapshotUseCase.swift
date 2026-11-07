//
//  LoadMonthEventsSnapshotUseCase.swift
//  cue / Domain
//

/// 마지막 실행이 저장한 월 캘린더 스냅샷 복원 — 앱 재시작 첫 페인트용. 없으면 nil(스피너 경로).
struct LoadMonthEventsSnapshotUseCase: Sendable {
    private let repository: any SnapshotCacheRepository

    init(repository: any SnapshotCacheRepository) {
        self.repository = repository
    }

    func callAsFunction() async -> MonthEventsSnapshot? {
        await repository.loadMonthEventsSnapshot()
    }
}
