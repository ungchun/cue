//
//  ISOWeekNumber.swift
//  cue / Shared
//

import Foundation

/// 1일·3일 위젯 좌상단에 붙는 주차 배지 계산 (레퍼런스의 `31`).
///
/// 기기 캘린더 설정(`Calendar.current.firstWeekday`)이 무엇이든 **ISO 8601 규칙 고정**으로
/// 계산한다 — 주차는 국제 표준 개념이라 주 시작 요일 설정에 따라 흔들리면 오히려 혼란스럽다.
/// ISO 규칙: 한 주는 월요일 시작이고, 그 주의 **목요일이 속한 해**가 그 주의 해다.
enum ISOWeekNumber {

    /// 주어진 날짜가 속한 ISO 주차(1...53).
    ///
    /// `calendar`에서는 **타임존만** 가져다 쓴다 — 날짜 경계는 지역에 따라야 하지만
    /// 주차 규칙 자체는 ISO로 고정해야 하기 때문이다.
    static func number(for date: Date, calendar: Calendar = .current) -> Int {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = calendar.timeZone
        return iso.component(.weekOfYear, from: date)
    }
}
