//
//  RecurrenceRule.swift
//  cue / Domain
//

import Foundation

/// 반복 알림의 주기 — EventKit `EKRecurrenceRule`을 도메인 형태로 받는다.
///
/// 빈도·간격에 더해 Apple 미리 알림 "사용자화" 수준의 지정을 담는다:
/// 매주 요일, 매월 일자 또는 서수 요일(N째 X요일), 매년 월, 반복 종료 날짜.
/// 표현 못 하는 규칙(횟수 종료 등)은 Data 계층 매퍼가 빈도·간격만으로 단순화하고 `isApproximate`로 표시한다.
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
    /// 매퍼가 EventKit 규칙을 다 못 담아 빈도·간격으로 단순화했는지(마지막 평일·마지막 날·횟수 종료 등).
    /// 이 값으로는 회차를 정확히 셀 수 없다 — "이 미리 알림만 삭제"가 엉뚱한 날로 옮기지 않게 표시한다.
    var isApproximate = false

    init(
        frequency: RecurrenceFrequency,
        interval: Int = 1,
        weekdays: Set<Int> = [],
        monthDays: Set<Int> = [],
        months: Set<Int> = [],
        ordinal: Int? = nil,
        ordinalWeekday: Int? = nil,
        endDate: Date? = nil,
        isApproximate: Bool = false
    ) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.weekdays = weekdays
        self.monthDays = monthDays
        self.months = months
        self.ordinal = ordinal
        self.ordinalWeekday = ordinalWeekday
        self.endDate = endDate
        self.isApproximate = isApproximate
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
        isApproximate = try container.decodeIfPresent(Bool.self, forKey: .isApproximate) ?? false
    }
}

/// 반복 주기 단위 — EventKit `EKRecurrenceFrequency`와 1:1.
enum RecurrenceFrequency: String, Equatable, Sendable, Codable {
    case daily
    case weekly
    case monthly
    case yearly
}

extension RecurrenceRule {
    /// `due` 다음 회차 중 `due`와 `now`보다 모두 뒤인 첫 회차 — 미리 알림 앱의 "이 미리 알림만 삭제"가
    /// 마감을 옮기는 곳(2026-11-09 실측: 11/6 매일 종일 → 11/7도 오늘도 아닌 11/10, 시각은 유지).
    /// 반복 종료일은 저장된 시각과 무관하게 그날 하루를 포함한다. 회차가 없으면 nil(마지막 회차).
    /// 간격은 `due`를 기준점으로 센다 — `due`가 곧 현재 회차라서.
    func nextOccurrence(after due: Date, now: Date, calendar: Calendar = .current) -> Date? {
        guard !isApproximate else { return nil }   // 단순화된 규칙으로 날을 지어내지 않는다
        let dueDay = calendar.startOfDay(for: due)
        let time = calendar.dateComponents([.hour, .minute, .second], from: due)
        let endDay = endDate.map { calendar.startOfDay(for: $0) }
        guard let dayAfterDue = calendar.date(byAdding: .day, value: 1, to: dueDay) else { return nil }
        var day = max(dayAfterDue, calendar.startOfDay(for: now))
        // ponytail: 하루씩 훑는다(최대 ~10년 × 간격, 2월 29일 매년도 덮음). 삭제 한 번에 한 번 도는 경로라 충분.
        for _ in 0..<(3_700 * interval) {
            if let endDay, day > endDay { return nil }
            if matches(day, anchor: dueDay, calendar: calendar),
               let occurrence = calendar.date(
                   bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: day
               ),
               occurrence > now {
                return occurrence
            }
            guard let following = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            day = following
        }
        return nil
    }

    /// `day`가 `anchor`(현재 회차의 날)에서 시작한 이 규칙의 회차인가.
    private func matches(_ day: Date, anchor: Date, calendar: Calendar) -> Bool {
        let d = calendar.dateComponents([.year, .month, .day, .weekday], from: day)
        let a = calendar.dateComponents([.year, .month, .day, .weekday], from: anchor)
        guard let dYear = d.year, let dMonth = d.month, let dDay = d.day, let dWeekday = d.weekday,
              let aYear = a.year, let aMonth = a.month, let aDay = a.day, let aWeekday = a.weekday
        else { return false }

        switch frequency {
        case .daily:
            let days = calendar.dateComponents([.day], from: anchor, to: day).day ?? 0
            return days % interval == 0
        case .weekly:
            guard (weekdays.isEmpty ? [aWeekday] : weekdays).contains(dWeekday),
                  let dayWeek = calendar.dateInterval(of: .weekOfYear, for: day)?.start,
                  let anchorWeek = calendar.dateInterval(of: .weekOfYear, for: anchor)?.start
            else { return false }
            let weeks = calendar.dateComponents([.weekOfYear], from: anchorWeek, to: dayWeek).weekOfYear ?? 0
            return weeks % interval == 0
        case .monthly:
            guard ((dYear - aYear) * 12 + dMonth - aMonth) % interval == 0 else { return false }
            if let ordinal, let ordinalWeekday {
                return isOrdinal(ordinal, weekday: ordinalWeekday, day: day, components: d, calendar: calendar)
            }
            return (monthDays.isEmpty ? [aDay] : monthDays).contains(dDay)
        case .yearly:
            guard (dYear - aYear) % interval == 0, (months.isEmpty ? [aMonth] : months).contains(dMonth)
            else { return false }
            if let ordinal, let ordinalWeekday {
                return isOrdinal(ordinal, weekday: ordinalWeekday, day: day, components: d, calendar: calendar)
            }
            return dDay == aDay
        }
    }

    /// `day`가 그 달의 `ordinal`째(-1 = 마지막) `weekday`인가.
    private func isOrdinal(
        _ ordinal: Int, weekday: Int, day: Date, components: DateComponents, calendar: Calendar
    ) -> Bool {
        guard components.weekday == weekday, let dayOfMonth = components.day else { return false }
        if ordinal > 0 { return (dayOfMonth - 1) / 7 + 1 == ordinal }
        let daysInMonth = calendar.range(of: .day, in: .month, for: day)?.count ?? 31
        return (daysInMonth - dayOfMonth) / 7 + 1 == -ordinal
    }
}
