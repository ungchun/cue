//
//  EventKitEventsRepository.swift
//  cue / Data
//

import EventKit

/// `EventsRepository`의 EventKit 구현 — iOS "캘린더"의 접근 권한을 도메인 용어로 노출한다.
///
/// 비-Sendable인 `EKEventStore`를 `actor`로 가둬 `Sendable`을 만족시킨다
/// (`EventKitRemindersRepository`와 같은 방식). 미리알림(`.reminder`)과 캘린더(`.event`)는
/// EventKit에서 서로 다른 권한이므로 각각 별도의 store/repository로 분리한다.
///
/// 신규 이벤트 입력은 Presentation 계층의 `EKEventEditViewController`가 직접 처리한다 —
/// 이 repository는 권한 게이트만 책임진다.
actor EventKitEventsRepository: EventsRepository {
    private let store = EKEventStore()

    func requestAccess() async -> EventsAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .writeOnly:
            // writeOnly도 새 이벤트 생성에는 충분하므로 granted로 본다.
            return .granted
        case .notDetermined:
            do {
                let granted = try await store.requestFullAccessToEvents()
                return granted ? .granted : .denied
            } catch {
                return .denied
            }
        default:
            // .denied, .restricted 등
            return .denied
        }
    }

    /// `[from, to)` 범위와 겹치는 이벤트를 모든 캘린더에서 모은다.
    /// `predicateForEvents(withStart:end:calendars:)`은 범위 경계와 겹치는
    /// 이벤트(straddling)를 자동 포함 — InMemory 구현과 의미론이 일치한다.
    /// `calendars: nil`은 사용자가 등록한 모든 캘린더를 대상으로 한다.
    func fetchEvents(from: Date, to: Date) async throws -> [CalendarEvent] {
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: nil)
        return store.events(matching: predicate).map(EventMapper.toEvent)
    }
}
