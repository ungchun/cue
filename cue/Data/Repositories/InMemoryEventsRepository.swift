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
    private var calendars: [EventCalendar]
    /// 변경 신호 stream. single-consumer 가정(테스트·ViewModel 1쌍). 다중 구독이 필요하면
    /// EventKit 구현처럼 NotificationCenter 패턴으로 바꾼다.
    private let changesStream: AsyncStream<Void>
    private let changesContinuation: AsyncStream<Void>.Continuation

    init(
        access: EventsAccess = .granted,
        events: [CalendarEvent] = [],
        calendars: [EventCalendar] = []
    ) {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        self.changesStream = stream
        self.changesContinuation = continuation
        self.access = access
        self.events = events
        self.calendars = calendars
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

    func fetchCalendars() async throws -> [EventCalendar] { calendars }

    nonisolated func changes() -> AsyncStream<Void> { changesStream }

    /// 테스트 헬퍼 — 변경 신호를 한 번 emit한다. 실 EventKit 구현은 NotificationCenter가
    /// 자동으로 emit하므로 외부에서 호출할 필요가 없다.
    func emitChange() {
        changesContinuation.yield(())
    }
}
