//
//  FetchReminderSortSettingsUseCase.swift
//  cue / Domain
//

import Foundation

/// 한 섹션의 정렬 설정을 불러온다.
struct FetchReminderSortSettingsUseCase: Sendable {
    let repository: any ReminderSortRepository

    func callAsFunction(scope: String) async -> ReminderSortSettings {
        await repository.fetch(scope: scope)
    }
}
