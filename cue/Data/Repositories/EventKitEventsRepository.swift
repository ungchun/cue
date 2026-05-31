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
}
