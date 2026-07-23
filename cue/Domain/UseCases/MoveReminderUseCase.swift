//
//  MoveReminderUseCase.swift
//  cue / Domain
//

/// 미리 알림을 다른 리스트로 옮긴다 — 전체 탭 섹션 간 드래그의 백엔드.
/// EventKit에선 항목의 calendar 교체에 해당한다.
struct MoveReminderUseCase: Sendable {
    private let repository: any RemindersRepository

    init(repository: any RemindersRepository) {
        self.repository = repository
    }

    func callAsFunction(reminderID: String, toListID listID: String) async throws {
        try await repository.moveReminder(reminderID: reminderID, toListID: listID)
    }
}
