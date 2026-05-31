//
//  InMemoryEventsRepository.swift
//  cue / Data
//

/// 프리뷰·테스트용 인메모리 구현. EventKit·권한 없이 동작한다.
///
/// `InMemoryRemindersRepository`와 동일한 형태 — `actor`로 격리해 `Sendable`을 만족한다.
actor InMemoryEventsRepository: EventsRepository {
    private var access: EventsAccess

    init(access: EventsAccess = .granted) {
        self.access = access
    }

    func requestAccess() async -> EventsAccess {
        if access == .notDetermined { access = .granted }
        return access
    }
}
