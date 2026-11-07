//
//  SaveScheduleDisplayModeUseCase.swift
//  cue / Domain
//

import Foundation

/// 일정 탭의 표시 모드를 영속 저장한다.
struct SaveScheduleDisplayModeUseCase: Sendable {
    let repository: any ScheduleDisplayModeRepository

    func callAsFunction(_ mode: ScheduleDisplayMode) {
        repository.save(mode)
    }
}
