//
//  MonthCalendarGrid.swift
//  cue / Shared
//

import Foundation

/// 잠금화면 Live Activity용 월간 캘린더 그리드의 순수 날짜 계산 모델.
///
/// 렌더(SwiftUI)와 분리해 단위 테스트 가능하게 둔다 — 앱·위젯 양쪽 타깃에 컴파일된다.
/// 공휴일은 알지 않는다(뷰가 별도로 합성). 색칠은 뷰가 `weekdayIndex(column:)`로 판단한다.
struct MonthCalendarGrid: Sendable {

    /// 표시 월의 연도.
    let year: Int
    /// 표시 월(1...12).
    let month: Int
    /// 표시 월 라벨 — "10월".
    let monthLabel: String
    /// 이전 달 라벨 — 네비 오버레이용. "9월"(1월이면 "12월"로 랩).
    let previousMonthLabel: String
    /// 다음 달 라벨 — 네비 오버레이용. "11월"(12월이면 "1월"로 랩).
    let nextMonthLabel: String
    /// 요일 헤더 심볼 — `firstWeekday` 순서. 매우 짧은 심볼(예: 일 월 화 …).
    let weekdaySymbols: [String]
    /// 주 단위 행(각 7칸). 표시 월 밖 칸은 `nil` — 1일 앞 여백·말일 뒤 여백. 필요한 만큼만(4~6행).
    let weeks: [[Int?]]

    /// 표시 월 첫날의 주 시작 요일. `weekdayIndex(column:)`가 요일을 되돌리는 데 쓴다.
    private let firstWeekday: Int
    /// `now`의 연·월·일 — `isToday`가 표시 월이 이번 달일 때만 오늘을 표시하려고 비교한다.
    private let todayYear: Int
    private let todayMonth: Int
    private let todayDay: Int

    /// `monthOffset`은 `now`의 달을 기준으로 표시 월을 앞뒤로 민다. 항상 `clampedOffset`으로 좁힌다.
    init(now: Date, monthOffset: Int, calendar: Calendar = .current) {
        let offset = Self.clampedOffset(monthOffset)

        let nowComponents = calendar.dateComponents([.year, .month, .day], from: now)
        self.todayYear = nowComponents.year ?? 0
        self.todayMonth = nowComponents.month ?? 0
        self.todayDay = nowComponents.day ?? 0

        // 표시 월의 1일 — now가 속한 달의 1일에서 offset개월 이동.
        let firstOfNowMonth = calendar.date(
            from: DateComponents(year: nowComponents.year, month: nowComponents.month, day: 1)
        ) ?? calendar.startOfDay(for: now)
        let firstOfMonth = calendar.date(byAdding: .month, value: offset, to: firstOfNowMonth) ?? firstOfNowMonth

        let displayed = calendar.dateComponents([.year, .month], from: firstOfMonth)
        self.year = displayed.year ?? 0
        self.month = displayed.month ?? 0

        self.firstWeekday = calendar.firstWeekday
        self.monthLabel = Self.monthFormatter.string(from: firstOfMonth)
        let prevMonth = calendar.date(byAdding: .month, value: -1, to: firstOfMonth) ?? firstOfMonth
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth) ?? firstOfMonth
        self.previousMonthLabel = Self.monthFormatter.string(from: prevMonth)
        self.nextMonthLabel = Self.monthFormatter.string(from: nextMonth)

        // 요일 헤더 — 시스템 심볼(0=일요일)을 firstWeekday 시작으로 회전.
        let symbols = Self.symbolFormatter.veryShortWeekdaySymbols ?? []
        self.weekdaySymbols = (0..<7).map { column in
            let index = ((calendar.firstWeekday - 1) + column) % 7
            return symbols.indices.contains(index) ? symbols[index] : ""
        }

        self.weeks = Self.makeWeeks(firstOfMonth: firstOfMonth, calendar: calendar)
    }

    /// 표시 월이 이번 달이고 그 날이 오늘일 때만 true.
    func isToday(day: Int) -> Bool {
        year == todayYear && month == todayMonth && day == todayDay
    }

    /// 해당 열의 요일(1=일 … 7=토) — 뷰가 일요일 빨강·토요일 회색을 칠하는 근거.
    func weekdayIndex(column: Int) -> Int {
        ((firstWeekday - 1) + column) % 7 + 1
    }

    /// offset을 -12...12로 좁힌다 — 탭 인텐트도 재사용하므로 공개한다.
    static func clampedOffset(_ offset: Int) -> Int {
        max(-12, min(12, offset))
    }

    // MARK: - 그리드 구성

    private static func makeWeeks(firstOfMonth: Date, calendar: Calendar) -> [[Int?]] {
        let firstWeekdayOfMonth = calendar.component(.weekday, from: firstOfMonth)
        // 1일 앞 여백 칸 수 — 주 시작 요일 기준.
        let leadingBlanks = (firstWeekdayOfMonth - calendar.firstWeekday + 7) % 7
        let dayCount = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 0

        var cells: [Int?] = Array(repeating: nil, count: leadingBlanks)
        cells.append(contentsOf: (1...dayCount).map { Optional($0) })
        // 마지막 행을 7칸으로 채우는 만큼만 뒤 여백 — 남는 빈 행은 만들지 않는다.
        let trailingBlanks = (7 - cells.count % 7) % 7
        cells.append(contentsOf: Array(repeating: nil, count: trailingBlanks))

        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMM")   // ko "10월" / en "October"
        return formatter
    }()

    private static let symbolFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current   // veryShortWeekdaySymbols — 기기 로케일(ko:일월화… / en:S M T…)
        return formatter
    }()
}
