//
//  ScheduleTimeText.swift
//  cue / Shared
//

import Foundation

/// 일정 행의 시간 문구 — 인앱 화면과 라이브 액티비티가 공유하는 단일 로직.
///
/// `groupDate`(그 행이 속한 날의 자정) 기준으로 분기한다:
/// - 종일: "하루 종일"
/// - 하루짜리: "오전 9:00 - 오전 10:00"
/// - 여러 날 걸침: 시작일 섹션 "오전 6:00 →", 종료일 섹션 "→ 오전 8:00", 사이 날 "진행 중"
enum ScheduleTimeText {
    static func string(
        start: Date,
        end: Date,
        isAllDay: Bool,
        groupDate: Date,
        calendar: Calendar = .current
    ) -> String {
        if isAllDay { return String(localized: "All day") }
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard startDay != endDay else {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
        if groupDate == startDay { return "\(formatter.string(from: start)) →" }
        if groupDate == endDay { return "→ \(formatter.string(from: end))" }
        return String(localized: "In progress")
    }

    /// 시각 표기 — 기기 로케일의 12/24시간·오전오후 규칙을 따른다(`j` = locale hour).
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        return formatter
    }()
}
