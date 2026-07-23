//
//  RemindersSnapshot.swift
//  cue / Domain
//

/// 할일 탭의 마지막 fetch 결과 스냅샷 — 앱 재시작 시 EventKit fetch를 기다리지 않고
/// 즉시 첫 페인트하기 위한 캐시 단위. 원본은 항상 EventKit이며, 이 스냅샷은 표시용
/// 힌트일 뿐이라 그리자마자 조용한 최신화(fetch)로 대체된다.
struct RemindersSnapshot: Equatable, Sendable, Codable {
    var lists: [ReminderList]
    var reminders: [Reminder]
}
