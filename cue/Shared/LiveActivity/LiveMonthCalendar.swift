//
//  LiveMonthCalendar.swift
//  cue / Shared
//

/// LA 잠금화면 월간 캘린더가 한 달을 그리는 데 필요한 조회 결과 한 묶음.
///
/// 일정 점과 공휴일을 **같이** 담는 이유는 둘 다 같은 EventKit 조회 한 번에서 나오기
/// 때문이다 — 따로 두면 같은 달을 두 번 조회하게 된다.
///
/// 둘 다 표시 월 기준 **일(1~31) 정수**로만 식별한다(→ `LiveMonthDot` 주석).
struct LiveMonthCalendar: Sendable {
    let dots: [LiveMonthDot]
    /// 공휴일인 날(일 숫자) — 캘린더가 그 날짜를 일요일과 같은 빨강으로 칠한다.
    let holidays: [Int]

    /// 캘린더를 안 그리거나 권한이 없을 때.
    static let empty = LiveMonthCalendar(dots: [], holidays: [])
}

/// 잠금화면 월간 캘린더를 싣는 ContentState — 메모·할일·일정 LA 셋이 모두 채택한다.
///
/// 두 필드를 **함께** 갱신하게 묶는다. 게시·재게시·월 이동까지 대입 지점이 아홉 군데라,
/// 따로 두면 한쪽만 갱신하는 자리가 생긴다(점은 새 달인데 공휴일은 이전 달인 상태).
protocol MonthCalendarCarrying {
    var monthEventDots: [LiveMonthDot] { get set }
    var monthHolidays: [Int] { get set }
}

extension MonthCalendarCarrying {
    mutating func applyMonthCalendar(_ month: LiveMonthCalendar) {
        monthEventDots = month.dots
        monthHolidays = month.holidays
    }
}
