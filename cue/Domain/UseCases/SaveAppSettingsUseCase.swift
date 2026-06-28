//
//  SaveAppSettingsUseCase.swift
//  cue / Domain
//

import Foundation

/// 앱 전역 설정을 영속 저장한다.
struct SaveAppSettingsUseCase: Sendable {
    let repository: any AppSettingsRepository

    func callAsFunction(_ settings: AppSettings) async {
        await repository.save(settings)
    }
}
