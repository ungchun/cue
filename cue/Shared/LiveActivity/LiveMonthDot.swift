//
//  LiveMonthDot.swift
//  cue / Shared
//

/// LA 잠금화면 월간 캘린더의 하루치 점 — 표시 월 안의 일(1~31) + 그날 항목 색.
///
/// 일정과 할일을 **함께**, 한 건당 한 칸 센다(홈 위젯 격자와 같은 규칙 → `MonthDotColors`).
///
/// `LiveDayEventDots`(주간 스트립용, `Date` 보관)와 달리 **일 정수만** 담아 ContentState
/// 크기를 최소화한다 — 한 달치 점을 실어도 ActivityKit 4KB 한도를 넘지 않게. 월간 캘린더는
/// 표시 월 한 달만 그리므로 일 숫자로 셀과 매칭하면 충분하다.
struct LiveMonthDot: Codable, Hashable, Sendable {
    let day: Int
    let colorHexes: [String]
}
