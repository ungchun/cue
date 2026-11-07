//
//  EventOccurrenceLocator.swift
//  cue / Presentation
//

import EventKit
import Foundation

/// `EventOccurrenceRef` → 실제 `EKEvent` 회차 조회.
///
/// `event(withIdentifier:)`는 반복 시리즈의 첫 회차를 주므로 쓰지 않고, 회차 시작 전후의
/// 좁은 창을 술어로 조회해 ID·시작 시각이 맞는 회차를 고른다. 고르는 규칙은 EventKit 없이
/// 테스트하려고 `select`로 분리했다.
enum EventOccurrenceLocator {
    /// 조회 창 반폭 — 종일 이벤트(자정 시작)·시간대 차이로 시작이 어긋나도 창 안에 들게 하루씩.
    private static let windowPadding: TimeInterval = 86_400

    /// 회차 조회. 창 안에서 못 찾으면 마지막으로 ID 조회(첫 회차라도 아무것도 없는 것보단 낫다).
    static func locate(_ ref: EventOccurrenceRef, in store: EKEventStore) -> EKEvent? {
        let predicate = store.predicateForEvents(
            withStart: ref.occurrenceStart.addingTimeInterval(-windowPadding),
            end: ref.occurrenceStart.addingTimeInterval(windowPadding),
            calendars: nil
        )
        let candidates = store.events(matching: predicate)
        return select(
            from: candidates, eventID: ref.eventID, occurrenceStart: ref.occurrenceStart,
            id: { $0.eventIdentifier }, start: { $0.startDate }
        ) ?? store.event(withIdentifier: ref.eventID)
    }

    /// 후보 중 ID가 같고 시작이 정확히 같은 회차 → 없으면 ID가 같은 것 중 시작이 가장 가까운 회차.
    /// ID가 같은 후보가 없으면 nil.
    static func select<Candidate>(
        from candidates: [Candidate],
        eventID: String,
        occurrenceStart: Date,
        id: (Candidate) -> String?,
        start: (Candidate) -> Date?
    ) -> Candidate? {
        let sameID = candidates.filter { id($0) == eventID }
        if let exact = sameID.first(where: { start($0) == occurrenceStart }) {
            return exact
        }
        // 시작이 없는 손상 후보는 가장 먼 것으로 취급한다.
        return sameID.min { lhs, rhs in
            distance(start(lhs), occurrenceStart) < distance(start(rhs), occurrenceStart)
        }
    }

    private static func distance(_ date: Date?, _ target: Date) -> TimeInterval {
        date.map { abs($0.timeIntervalSince(target)) } ?? .infinity
    }
}
