//
//  FetchAppSettingsUseCase.swift
//  cue / Domain
//

import Foundation

/// 앱 전역 설정을 불러온다.
struct FetchAppSettingsUseCase: Sendable {
    let repository: any AppSettingsRepository

    func callAsFunction() async -> AppSettings {
        await repository.fetch()
    }
}
