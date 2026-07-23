//
//  EventsSnapshot.swift
//  cue / Domain
//

import Foundation

/// 일정 탭의 마지막 fetch 결과 스냅샷 — `RemindersSnapshot`과 같은 첫 페인트용 캐시.
/// `fetchedUntil`은 저장 당시 fetch 범위의 끝(오늘 → until)이다. 복원 시점에 이 값이
/// 이미 과거면 캐시 범위가 화면에 보여줄 게 없다는 뜻이므로 호출자가 버린다.
struct EventsSnapshot: Equatable, Sendable, Codable {
    var events: [CalendarEvent]
    var fetchedUntil: Date
}
