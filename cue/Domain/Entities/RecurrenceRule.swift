//
//  RecurrenceRule.swift
//  cue / Domain
//

import Foundation

/// 반복 알림의 주기 — EventKit `EKRecurrenceRule`을 도메인 형태로 받는다.
///
/// 빈도·간격에 더해 Apple 미리 알림 "사용자화" 수준의 지정을 담는다:
/// 매주 요일, 매월 일자 또는 서수 요일(N째 X요일), 매년 월, 반복 종료 날짜.
/// 표현 못 하는 규칙(횟수 종료 등)은 Data 계층 매퍼가 빈도·간격만으로 단순화한다.
struct RecurrenceRule: Equatable, Sendable, Codable {
    let frequency: RecurrenceFrequency
    /// 주기 간격 — `매일`이면 1, `2일마다`면 2. 음수·0은 1로 보정한다.
    let interval: Int
    /// 매주 반복의 요일(1=일 … 7=토). 비면 시작(마감)일 요일을 따른다.
    var weekdays: Set<Int> = []
    /// 매월 반복의 일자(1…31). 비면 마감일 일자. `ordinal` 지정 시 무시.
    var monthDays: Set<Int> = []
    /// 매년 반복의 월(1…12). 비면 마감일 월.
    var months: Set<Int> = []
    /// 서수 요일("N째 X요일") — 1…5 = 첫째…다섯째, -1 = 마지막. 매월·매년에서만 의미.
    var ordinal: Int?
    /// 서수 요일의 요일(1=일 … 7=토). `ordinal`과 항상 짝.
    var ordinalWeekday: Int?
    /// 반복 종료 날짜. nil이면 무기한.
    var endDate: Date?

    init(
        frequency: RecurrenceFrequency,
        interval: Int = 1,
        weekdays: Set<Int> = [],
        monthDays: Set<Int> = [],
        months: Set<Int> = [],
        ordinal: Int? = nil,
        ordinalWeekday: Int? = nil,
        endDate: Date? = nil
    ) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.weekdays = weekdays
        self.monthDays = monthDays
        self.months = months
        self.ordinal = ordinal
        self.ordinalWeekday = ordinalWeekday
        self.endDate = endDate
    }

    // 새 필드는 decodeIfPresent — 빈도·간격만 담긴 옛 스냅샷(JSON)도 그대로 읽힌다.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        frequency = try container.decode(RecurrenceFrequency.self, forKey: .frequency)
        interval = max(1, try container.decode(Int.self, forKey: .interval))
        weekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .weekdays) ?? []
        monthDays = try container.decodeIfPresent(Set<Int>.self, forKey: .monthDays) ?? []
        months = try container.decodeIfPresent(Set<Int>.self, forKey: .months) ?? []
        ordinal = try container.decodeIfPresent(Int.self, forKey: .ordinal)
        ordinalWeekday = try container.decodeIfPresent(Int.self, forKey: .ordinalWeekday)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
    }
}

/// 반복 주기 단위 — EventKit `EKRecurrenceFrequency`와 1:1.
enum RecurrenceFrequency: String, Equatable, Sendable, Codable {
    case daily
    case weekly
    case monthly
    case yearly
}
