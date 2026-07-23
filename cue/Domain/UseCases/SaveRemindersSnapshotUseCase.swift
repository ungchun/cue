//
//  SaveRemindersSnapshotUseCase.swift
//  cue / Domain
//

/// fetch 성공 결과를 할일 스냅샷으로 저장 — 다음 실행의 첫 페인트 재료.
struct SaveRemindersSnapshotUseCase: Sendable {
    private let repository: any SnapshotCacheRepository

    init(repository: any SnapshotCacheRepository) {
        self.repository = repository
    }

    func callAsFunction(_ snapshot: RemindersSnapshot) async {
        await repository.saveRemindersSnapshot(snapshot)
    }
}
