//
//  ScheduleDisplayModeRepository.swift
//  cue / Domain
//

import Foundation

/// 일정 탭의 마지막 표시 모드(타임라인/월 캘린더)를 영속 저장한다.
///
/// 왜 동기인가 — 모드는 첫 프레임을 그리기 **전에** 정해져야 타임라인이 잠깐 보였다가
/// 바뀌지 않는다. UserDefaults는 동기 저장소라 async 경계를 둘 이유가 없다.
protocol ScheduleDisplayModeRepository: Sendable {
    /// 저장된 모드. 저장된 값이 없거나 알 수 없는 값이면 nil.
    func fetch() -> ScheduleDisplayMode?
    /// 모드를 영속 저장 — 기존 값 덮어쓰기.
    func save(_ mode: ScheduleDisplayMode)
}
