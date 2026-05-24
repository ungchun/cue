//
//  DeleteReminderListUseCase.swift
//  cue / Domain
//

/// 리스트를 삭제한다 — 안에 있는 모든 미리알림 항목도 EventKit이 함께 제거한다.
/// 호출자(ViewModel)는 삭제 후 `selectedListID`를 다른 리스트로 옮겨야 한다.
struct DeleteReminderListUseCase: Sendable {
    private let repository: any RemindersRepository

    init(repository: any RemindersRepository) {
        self.repository = repository
    }

    func callAsFunction(listID: String) async throws {
        try await repository.deleteList(listID: listID)
    }
}
