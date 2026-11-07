//
//  UserDefaultsScheduleDisplayModeRepository.swift
//  cue / Data
//

import Foundation

/// `ScheduleDisplayModeRepository`의 UserDefaults 구현 — 모드의 rawValue 문자열 하나를
/// 한 키에 저장한다. 로컬 전용, iCloud 동기화 없음.
struct UserDefaultsScheduleDisplayModeRepository: ScheduleDisplayModeRepository, @unchecked Sendable {
    private static let storageKey = "cue.scheduleDisplayMode.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 없거나 모르는 값(옛/깨진 데이터)이면 nil — 호출부가 기본 모드로 대체한다.
    func fetch() -> ScheduleDisplayMode? {
        defaults.string(forKey: Self.storageKey).flatMap(ScheduleDisplayMode.init(rawValue:))
    }

    func save(_ mode: ScheduleDisplayMode) {
        defaults.set(mode.rawValue, forKey: Self.storageKey)
    }
}
