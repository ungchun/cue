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

    /// 상태-전용 조회 — 프롬프트를 절대 띄우지 않는다(앱 시작 프리페치 경로).
    /// `requestAccess`와 같은 매핑: writeOnly도 granted로 본다.
    func currentAccess() async -> EventsAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .writeOnly: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
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

    /// 이벤트를 담을 수 있는 모든 캘린더를 도메인 타입으로 돌려준다 — 설정 체크리스트용.
    func fetchCalendars() async throws -> [EventCalendar] {
        store.calendars(for: .event).map(EventMapper.toCalendar)
    }

    /// `EKEventStoreChanged`는 미리알림·캘린더 변경 모두에 발송되는 공통 노티 — events 측은
    /// 그 중 캘린더 변경에 대응한다. 구독자 측에서 stream을 종료해도 안에서 만든 Task가
    /// 자동 cancel되도록 `onTermination`에 연결.
    nonisolated func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged) {
                    if Task.isCancelled { break }
                    continuation.yield(())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
