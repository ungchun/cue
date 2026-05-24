//
//  AddReminderListUseCase.swift
//  cue / Domain
//

import Foundation

/// 새 미리알림 리스트(섹션)를 만든다. 제목 검증은 여기서 — 빈 제목은 만들지 않는다.
/// 만들어진 리스트 ID를 반환해 호출자가 곧장 그 리스트를 선택할 수 있게 한다.
struct AddReminderListUseCase: Sendable {
    private let repository: any RemindersRepository

    init(repository: any RemindersRepository) {
        self.repository = repository
    }

    func callAsFunction(title: String, colorHex: String?) async throws -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.validation("목록 이름을 입력해 주세요.")
        }
        return try await repository.addList(title: trimmed, colorHex: colorHex)
    }
}
