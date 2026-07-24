//
//  ScheduleLiveActivityMockCases.swift
//  cue / Presentation
//
//  ⚠️ 임시 — 일정 라이브 액티비티 레이아웃 눈 검증용 mock 케이스 모음.
//  `ScheduleViewModel.usesLiveActivityMockCases`가 true면 라이브 버튼이 실제 일정 대신
//  이 케이스들을 순회 게시한다. 검증이 끝나면 플래그와 함께 이 파일을 삭제한다.
//

import Foundation

enum ScheduleLiveActivityMockCases {
    struct Case {
        let name: String
        var events: [CalendarEvent]
    }

    /// 케이스 목록 — 첫 이벤트 제목에 "n/총 이름"을 박아 잠금화면에서 지금 몇 번째인지 보이게 한다.
    static func all(now: Date = .now) -> [Case] {
        var cases: [Case] = []
        cases.append(fullBothColumns(now: now))
        cases.append(Case(name: "없음", events: []))
        cases.append(single(now: now))
        cases.append(three(now: now))
        cases.append(allDayOnly(now: now))
        cases.append(oneDaySplit(now: now))
        cases.append(longTitles(now: now))
        cases.append(cjkEmoji(now: now))
        // 첫 이벤트 제목에 케이스 번호·이름 태깅 — 잠금화면에서 어느 케이스인지 식별.
        for index in cases.indices where !cases[index].events.isEmpty {
            cases[index].events[0].title =
                "[\(index + 1)/\(cases.count) \(cases[index].name)] " + cases[index].events[0].title
        }
        return cases
    }

    private static func fullBothColumns(now: Date) -> Case {
        var events: [CalendarEvent] = []
        events.append(allDay("종일 워크샵", dayOffset: 0, color: "#FF9500", now: now))
        events.append(allDay("건강검진", dayOffset: 0, color: "#FFCC00", now: now))
        events.append(timed("팀 회의", minutesFromNow: 30, color: "#007AFF", now: now))
        events.append(timed("디자인 리뷰", minutesFromNow: 120, color: "#AF52DE", now: now))
        events.append(timed("저녁 약속", minutesFromNow: 240, color: "#FF2D55", now: now))
        events.append(timed("월간 결산 보고", dayOffset: 1, hour: 11, color: "#007AFF", now: now))
        events.append(timed("고객 미팅", dayOffset: 1, hour: 14, color: "#AF52DE", now: now))
        events.append(timed("헬스", dayOffset: 1, hour: 19, color: "#34C759", now: now))
        events.append(timed("작업실 정리", dayOffset: 2, hour: 10, color: "#FF6482", now: now))
        events.append(timed("데이터 백업", dayOffset: 2, hour: 15, color: "#5856D6", now: now))
        events.append(timed("주간 리뷰", dayOffset: 3, hour: 9, color: "#FF9500", now: now))
        events.append(timed("가족 저녁", dayOffset: 3, hour: 18, color: "#34C759", now: now))
        return Case(name: "양쪽 꽉참", events: events)
    }

    private static func single(now: Date) -> Case {
        Case(name: "1개", events: [
            timed("혼자 있는 일정", minutesFromNow: 60, color: "#007AFF", now: now),
        ])
    }

    private static func three(now: Date) -> Case {
        Case(name: "3개", events: [
            timed("첫 번째", minutesFromNow: 30, color: "#007AFF", now: now),
            timed("두 번째", minutesFromNow: 90, color: "#AF52DE", now: now),
            timed("세 번째", minutesFromNow: 180, color: "#34C759", now: now),
        ])
    }

    private static func allDayOnly(now: Date) -> Case {
        Case(name: "종일만", events: [
            allDay("휴가", dayOffset: 0, color: "#5AC8FA", now: now),
            allDay("워크샵", dayOffset: 0, color: "#FF9500", now: now),
            allDay("기념일", dayOffset: 1, color: "#FF2D55", now: now),
            allDay("출장", dayOffset: 2, color: "#5856D6", now: now),
        ])
    }

    private static func oneDaySplit(now: Date) -> Case {
        let events = (0..<7).map { index in
            timed("연속 일정 \(index + 1)", minutesFromNow: 30 + index * 60, color: "#007AFF", now: now)
        }
        return Case(name: "한 날 연속분할", events: events)
    }

    private static func longTitles(now: Date) -> Case {
        Case(name: "긴 제목", events: [
            timed("아주아주 길어서 한 줄에 절대 다 안 들어가는 일정 제목의 말줄임 확인",
                  minutesFromNow: 30, color: "#FF9500", now: now),
            allDay("종일인데도 제목이 길어서 캡슐 가운데 정렬과 말줄임이 어떻게 보이는지",
                   dayOffset: 0, color: "#34C759", now: now),
            timed("내일도 긴 제목 하나 — 열 너비 대비 줄임표 위치 확인용 텍스트",
                  dayOffset: 1, hour: 10, color: "#AF52DE", now: now),
        ])
    }

    private static func cjkEmoji(now: Date) -> Case {
        Case(name: "CJK·이모지", events: [
            allDay("🏝️ 休暇スタート", dayOffset: 0, color: "#5AC8FA", now: now),
            timed("工作坊及团队建设", minutesFromNow: 45, color: "#FF9500", now: now),
            timed("🎂 Birthday dinner", minutesFromNow: 150, color: "#FF2D55", now: now),
            timed("月度结算报告", dayOffset: 1, hour: 11, color: "#007AFF", now: now),
        ])
    }

    /// 시간 이벤트 — 오늘은 `minutesFromNow`로 지금 이후에 두어 "끝난 일정 숨김" 필터를 피하고,
    /// 다른 날은 `dayOffset`+`hour`의 절대 시각으로 만든다.
    private static func timed(
        _ title: String, minutesFromNow: Int = 0, dayOffset: Int = 0, hour: Int? = nil,
        color: String, now: Date
    ) -> CalendarEvent {
        let calendar = Calendar.current
        let start: Date
        if let hour, dayOffset > 0 {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) ?? now
            start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        } else {
            start = now.addingTimeInterval(TimeInterval(minutesFromNow * 60))
        }
        return CalendarEvent(
            id: UUID().uuidString, title: title,
            startDate: start, endDate: start.addingTimeInterval(3600),
            isAllDay: false, calendarColorHex: color, isReadOnly: true
        )
    }

    private static func allDay(_ title: String, dayOffset: Int, color: String, now: Date) -> CalendarEvent {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) ?? now
        return CalendarEvent(
            id: UUID().uuidString, title: title,
            startDate: day, endDate: day.addingTimeInterval(24 * 3600 - 1),
            isAllDay: true, calendarColorHex: color, isReadOnly: true
        )
    }
}
