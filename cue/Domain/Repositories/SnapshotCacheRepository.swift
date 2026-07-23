//
//  SnapshotCacheRepository.swift
//  cue / Domain
//

/// 첫 페인트용 스냅샷 캐시 경계 — 마지막 fetch 결과를 저장·복원한다.
///
/// 원본 저장소(EventKit)가 아니라 표시용 캐시라 실패를 던지지 않는다 — 저장 실패는
/// 조용히 무시(다음 fetch가 다시 시도), 복원 실패·부재는 nil(호출자가 스피너 경로로).
protocol SnapshotCacheRepository: Sendable {
    func loadRemindersSnapshot() async -> RemindersSnapshot?
    func saveRemindersSnapshot(_ snapshot: RemindersSnapshot) async
    func loadEventsSnapshot() async -> EventsSnapshot?
    func saveEventsSnapshot(_ snapshot: EventsSnapshot) async
}
