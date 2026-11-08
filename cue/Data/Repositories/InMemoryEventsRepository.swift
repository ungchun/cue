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

    /// 프롬프트 시뮬레이션(미결정→허용) 없이 상태 그대로 — 프리페치 가드 테스트의 관측점.
    func currentAccess() async -> EventsAccess {
        access
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

    /// 캐시가 없다 — 조회가 늘 현재 값을 돌려준다.
    func discardCache() {}

    /// 테스트 헬퍼 — 변경 신호를 한 번 emit한다. 실 EventKit 구현은 NotificationCenter가
    /// 자동으로 emit하므로 외부에서 호출할 필요가 없다.
    func emitChange() {
        changesContinuation.yield(())
    }

    /// 테스트 헬퍼 — 변경 신호 없이 이벤트를 넣는다. 시트가 EventKit에 직접 저장했는데
    /// `EKEventStoreChanged`가 오지 않는 경우를 흉내 낸다.
    func insertSilently(_ event: CalendarEvent) {
        events.append(event)
    }

    /// 테스트 헬퍼 — 같은 id의 이벤트를 변경 신호 없이 바꾼다. 시트가 기존 일정을 수정한 경우.
    func updateSilently(_ event: CalendarEvent) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[index] = event
    }
}
