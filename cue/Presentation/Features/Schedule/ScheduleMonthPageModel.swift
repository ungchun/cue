//
//  ScheduleMonthPageModel.swift
//  cue / Presentation
//

import Foundation
import Observation

/// 월 캘린더 한 달(한 페이지)의 표시 상태.
///
/// 달마다 따로 관찰되게 VM의 사전 하나에서 떼어 냈다 — 사전 하나면 한 달이 갱신될 때
/// 그 사전을 읽는 모든 페이지가 다시 그려진다. 갱신은 `ScheduleMonthViewModel`만 한다.
@MainActor
@Observable
final class ScheduleMonthPageModel {
    /// 이 페이지 달의 1일 자정 — VM 캐시 키와 같다.
    let monthStart: Date
    /// 격자 — 날짜 포매터를 만드므로 페이지당 한 번만 계산한다. 날이 바뀌면 VM이 `refreshGrid`로 갈아 끼운다.
    private(set) var grid: MonthCalendarGrid
    /// 캐시든 조회든 한 번이라도 채워졌는지 — false면 페이지가 스피너.
    private(set) var isLoaded = false

    /// 날짜 숫자 → 그 날 항목.
    private var itemsByDay: [Int: [WidgetCalendarItem]] = [:]
    /// 날짜 숫자 → 그 날 날씨 SF Symbol 이름. 예보가 있는 날(오늘부터 약 10일)만.
    private var weatherByDay: [Int: String] = [:]
    /// 날짜 숫자 → 음력 표기("10.14"). 음력 표시 설정이 켜져 있고 한국 지역일 때만 채워진다.
    private var lunarByDay: [Int: String] = [:]

    init(monthStart: Date, now: Date, calendar: Calendar = .current) {
        self.monthStart = monthStart
        self.grid = MonthCalendarGrid(firstOfMonth: monthStart, now: now, calendar: calendar)
    }

    /// 그 날 항목(없으면 빈 배열).
    func items(day: Int) -> [WidgetCalendarItem] {
        itemsByDay[day] ?? []
    }

    /// 그 날 날씨 아이콘 이름(예보가 없으면 nil).
    func weatherSymbol(day: Int) -> String? {
        weatherByDay[day]
    }

    /// 그 날 음력 표기(표시 안 하면 nil).
    func lunarLabel(day: Int) -> String? {
        lunarByDay[day]
    }

    // MARK: - VM 전용 갱신

    /// 항목·날씨·음력을 채우고 적재 완료로 표시한다. 같은 내용이면 건드리지 않는다 — 캐시를 그린 뒤
    /// 조회 결과가 같을 때 페이지가 한 번 더 그려지지 않게.
    func apply(
        itemsByDay newItems: [Int: [WidgetCalendarItem]],
        weatherByDay newWeather: [Int: String] = [:],
        lunarByDay newLunar: [Int: String] = [:]
    ) {
        if itemsByDay != newItems { itemsByDay = newItems }
        if weatherByDay != newWeather { weatherByDay = newWeather }
        if lunarByDay != newLunar { lunarByDay = newLunar }
        if !isLoaded { isLoaded = true }
    }

    /// 윈도우 밖으로 축출될 때 — 항목을 비워 메모리를 돌려준다. 뷰가 아직 붙들고 있어도
    /// 다시 윈도우에 들어오면 VM이 같은 객체를 채운다.
    func reset() {
        if !itemsByDay.isEmpty { itemsByDay = [:] }
        if !weatherByDay.isEmpty { weatherByDay = [:] }
        if !lunarByDay.isEmpty { lunarByDay = [:] }
        if isLoaded { isLoaded = false }
    }

    /// 날이 바뀌었을 때 오늘 표시를 맞춘다.
    func refreshGrid(now: Date, calendar: Calendar = .current) {
        grid = MonthCalendarGrid(firstOfMonth: monthStart, now: now, calendar: calendar)
    }
}
