//
//  RecurrenceRule.swift
//  cue / Domain
//

import Foundation

/// 반복 알림의 주기 — EventKit `EKRecurrenceRule`을 도메인 단순화 형태로 받는다.
///
/// 이번 단계는 `frequency` + `interval`(1 이상)까지만. `매주 월·수` 같은 daysOfWeek,
/// 종료 조건 등 풍부한 표현은 다음 사이클에서 모델을 확장한다.
struct RecurrenceRule: Equatable, Sendable {
    let frequency: RecurrenceFrequency
    /// 주기 간격 — `매일`이면 1, `2일마다`면 2. 음수·0은 1로 보정한다.
    let interval: Int

    init(frequency: RecurrenceFrequency, interval: Int = 1) {
        self.frequency = frequency
        self.interval = max(1, interval)
    }
}

/// 반복 주기 단위 — EventKit `EKRecurrenceFrequency`와 1:1.
enum RecurrenceFrequency: String, Equatable, Sendable {
    case daily
    case weekly
    case monthly
    case yearly
}
