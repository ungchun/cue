//
//  InMemoryEventsRepository.swift
//  cue / Data
//

import Foundation

/// 프리뷰·테스트용 인메모리 구현. EventKit·권한 없이 동작한다.
///
/// `InMemoryRemindersRepository`와 동일한 형태 — `actor`로 격리해 `Sendable`을 만족한다.
actor InMemoryEventsRepository: EventsRepository {
    private var access: EventsAccess
    private var events: [CalendarEvent]

    init(access: EventsAccess = .granted, events: [CalendarEvent] = []) {
        self.access = access
        self.events = events
    }

    func requestAccess() async -> EventsAccess {
        if access == .notDetermined { access = .granted }
        return access
    }

    /// `[from, to)` 범위와 겹치는 이벤트만 돌려준다 (start < to && end > from).
    /// EventKit `predicateForEvents`의 겹침 규칙과 일치.
    func fetchEvents(from: Date, to: Date) async throws -> [CalendarEvent] {
        events.filter { event in
            event.startDate < to && event.endDate > from
        }
    }
}
