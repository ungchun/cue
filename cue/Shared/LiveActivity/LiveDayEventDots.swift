//
//  LiveDayEventDots.swift
//  cue / Shared
//

import Foundation

/// Dynamic Island 주간 캘린더 스트립의 하루치 "일정 있음" 점 묶음.
///
/// 그날 캘린더 이벤트마다 점 하나, 색은 그 이벤트가 속한 캘린더 색(`"#RRGGBB"`). 위젯은
/// 날짜 연산 없이 `dayStart`(그날 자정)로 스트립 각 칸과 매칭해 숫자 아래에 점을 그린다.
/// 색은 EventKit이 준 raw hex 그대로 — 디자인 시스템 컬러 규칙의 외부 데이터 예외.
struct LiveDayEventDots: Codable, Hashable, Sendable {
    let dayStart: Date
    let colorHexes: [String]
}
