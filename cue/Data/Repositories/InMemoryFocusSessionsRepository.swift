//
//  InMemoryFocusSessionsRepository.swift
//  cue / Data
//

/// 테스트·프리뷰용 인메모리 `FocusSessionsRepository`. 앱이 살아 있는 동안만 보존.
actor InMemoryFocusSessionsRepository: FocusSessionsRepository {
    private var stored: [FocusSession]

    init(sessions: [FocusSession] = []) {
        self.stored = sessions
    }

    func fetchAll() -> [FocusSession] {
        stored
    }

    func save(_ sessions: [FocusSession]) {
        stored = sessions
    }
}
