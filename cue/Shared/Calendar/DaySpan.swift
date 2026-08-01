//
//  DaySpan.swift
//  cue / Shared
//

import Foundation

/// 일정 하나가 **어느 날들에 걸치는지**를 정하는 단 하나의 규칙.
///
/// 위젯 격자(`WidgetCalendarDataSource`)와 LA 월간 캘린더(`LiveMonthCalendarProvider`)가
/// 같은 답을 내야 해서 여기 모았다. 예전엔 둘이 따로 계산했고, 그중 한쪽만 아래 보정을
/// 갖고 있어서 같은 공휴일이 위젯에선 하루, LA에선 이틀로 칠해질 수 있었다.
///
/// ## 끝 날짜를 1초 당기는 이유
///
/// iCalendar(ICS) 표준의 `DTEND`는 **배타적**이다 — 8/15 하루짜리 종일 일정이
/// "8/15 00:00 ~ 8/16 00:00"으로 표현된다. 공휴일 캘린더는 구독(ICS) 기반이라 이 형태로
/// 들어올 수 있고, 그대로 훑으면 다음 날까지 공휴일로 칠해진다. 시각이 있는 일정도 마찬가지다
/// — 23시에 시작해 자정에 끝나는 일정이 다음 날 칸까지 번진다.
///
/// EventKit이 종일 일정을 마지막 날 23:59:59로 정규화해 주는 경우도 있어 **두 형태가 섞여
/// 들어온다**. 1초를 당기면 둘 다 같은 답이 된다(23:59:59 → 23:59:58, 다음 날 00:00 →
/// 전날 23:59:59). 어느 쪽으로 오는지 알아낼 필요 자체가 없어진다.
///
/// 길이가 0인 항목(미리알림은 `start == end`)에는 보정을 걸지 않는다 — 당기면 전날로 밀린다.
enum DaySpan {

    /// `[start, end]`가 걸치는 날들의 **자정 목록**(오름차순). 최소 하루는 돌려준다.
    static func days(from start: Date, to end: Date, calendar: Calendar = .current) -> [Date] {
        let first = calendar.startOfDay(for: start)
        // 끝이 시작보다 앞선 깨진 데이터도 시작일 하루로 접는다.
        let rawEnd = max(start, end)
        let lastMoment = rawEnd > start ? rawEnd.addingTimeInterval(-1) : rawEnd
        let last = max(first, calendar.startOfDay(for: lastMoment))

        var result: [Date] = []
        var cursor = first
        while cursor <= last {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }
}
