//
//  SaveReminderSortSettingsUseCase.swift
//  cue / Domain
//

import Foundation

/// 한 섹션의 정렬 설정을 영속 저장한다.
struct SaveReminderSortSettingsUseCase: Sendable {
    let repository: any ReminderSortRepository

    func callAsFunction(_ settings: ReminderSortSettings, scope: String) async {
        await repository.save(settings, scope: scope)
    }
}
