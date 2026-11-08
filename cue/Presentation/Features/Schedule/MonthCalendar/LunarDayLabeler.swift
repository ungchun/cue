//
//  LunarDayLabeler.swift
//  cue / Presentation
//

import Foundation

/// 양력 날짜 → 월 캘린더 칸의 음력 표기("10.14", 윤달이면 "윤4.3").
///
/// 한국 음력은 `.dangi`로 계산한다 — `.chinese`는 중국 표준시 기준이라 삭(朔)이 자정 무렵이면
/// 한국 달력과 하루가 어긋나고, 윤달이 다른 달에 들기도 한다(예: 2017년 한국 윤5월 ↔ 중국 윤6월).
struct LunarDayLabeler {
    /// 윤달 표기 — 한국 지역에서만 노출되는 기능이라 한국 달력 관례를 그대로 쓴다.
    private static let leapMonthPrefix = "윤"

    private let lunarCalendar = Calendar(identifier: .dangi)

    /// 그 날의 음력 표기. `calendar`의 시간대로 날을 가른다 — 칸의 양력 날과 같은 날을 보게.
    func label(for date: Date, calendar: Calendar = .current) -> String? {
        label(for: date, lunar: lunarCalendar(matching: calendar))
    }

    /// 그 달 모든 날의 음력 표기 — 양력 날짜 숫자 → 표기. 월 페이지 하나를 한 번에 채운다.
    func labels(monthStart: Date, calendar: Calendar = .current) -> [Int: String] {
        guard let days = calendar.range(of: .day, in: .month, for: monthStart) else { return [:] }
        let lunar = lunarCalendar(matching: calendar)
        var components = calendar.dateComponents([.year, .month], from: monthStart)
        // 정오로 잡는다 — 서머타임으로 자정이 없는 날에도 그 날 안의 시각이 되게.
        components.hour = 12
        var result: [Int: String] = [:]
        result.reserveCapacity(days.count)
        for day in days {
            components.day = day
            guard let date = calendar.date(from: components),
                  let text = label(for: date, lunar: lunar) else { continue }
            result[day] = text
        }
        return result
    }

    private func lunarCalendar(matching calendar: Calendar) -> Calendar {
        var lunar = lunarCalendar
        lunar.timeZone = calendar.timeZone
        return lunar
    }

    private func label(for date: Date, lunar: Calendar) -> String? {
        let parts = lunar.dateComponents([.month, .day], from: date)
        guard let month = parts.month, let day = parts.day else { return nil }
        let prefix = parts.isLeapMonth == true ? Self.leapMonthPrefix : ""
        return "\(prefix)\(month).\(day)"
    }
}
