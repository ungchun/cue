//
//  InMemoryFocusSessionsRepository.swift
//  cue / Data
//

import Foundation

/// 테스트·프리뷰용 인메모리 `FocusSessionsRepository`. 앱이 살아 있는 동안만 보존.
actor InMemoryFocusSessionsRepository: FocusSessionsRepository {
    private var stored: [FocusSession]
    private var selectedID: UUID?
    private var activeSession: ActiveFocusSessionSnapshot?

    init(sessions: [FocusSession] = [], selectedID: UUID? = nil) {
        self.stored = sessions
        self.selectedID = selectedID
    }

    func fetchAll() -> [FocusSession] {
        stored
    }

    func save(_ sessions: [FocusSession]) {
        stored = sessions
    }

    func fetchSelectedSessionID() -> UUID? {
        selectedID
    }

    func saveSelectedSessionID(_ id: UUID?) {
        selectedID = id
    }

    func fetchActiveSession() -> ActiveFocusSessionSnapshot? {
        activeSession
    }

    func saveActiveSession(_ snapshot: ActiveFocusSessionSnapshot?) {
        activeSession = snapshot
    }
}
