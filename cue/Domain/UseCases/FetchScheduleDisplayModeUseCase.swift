//
//  FetchScheduleDisplayModeUseCase.swift
//  cue / Domain
//

import Foundation

/// 일정 탭이 처음 보여줄 표시 모드를 **동기로** 읽는다. 저장값이 없으면 월 캘린더.
/// (첫 프레임 전에 정해져야 해서 동기 — `FetchStartTabIDUseCase`와 같은 이유.)
struct FetchScheduleDisplayModeUseCase: Sendable {
    let repository: any ScheduleDisplayModeRepository

    func callAsFunction() -> ScheduleDisplayMode {
        repository.fetch() ?? .month
    }
}
