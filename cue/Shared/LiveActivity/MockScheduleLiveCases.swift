//
//  MockScheduleLiveCases.swift
//  cue / Shared
//
//  ⚠️ 임시 — 일정 라이브 액티비티 레이아웃 눈 검증용 mock 케이스 + LA 위 ‹ › 전환 인텐트.
//  `ScheduleViewModel.enablesLiveActivityMockBrowsing`이 true면 앱이 `modeKey`를 켜고,
//  위젯이 그 키를 읽어 카드 좌우에 셰브런을 띄운다. 검증이 끝나면 플래그·이 파일·위젯의
//  셰브런 오버레이를 함께 제거한다.
//
//  타깃 멤버십: 위젯이 `Button(intent:)`로 참조하므로 앱 + 익스텐션 양쪽에 컴파일된다.
//  앱 전용(Domain) 타입은 참조하지 않는다 — `LiveScheduleDay`/`ScheduleTimeText`만 사용.
//

@preconcurrency import ActivityKit
import AppIntents
import Foundation

enum MockScheduleLiveCases {
    /// 위젯이 셰브런을 보일지 읽는 App Group 키 — 앱(뷰모델)이 게시 시점에 쓴다.
    static let modeKey = "cue.debug.mockScheduleCases.enabled"
    /// 현재 표시 중인 케이스 인덱스 — 인텐트가 순환 갱신한다.
    static let indexKey = "cue.debug.mockScheduleCases.index"

    struct MockCase {
        let name: String
        let days: [LiveScheduleDay]
        var todayCount: Int {
            days.first { $0.label == "오늘" }?.events.count ?? 0
        }
    }

    static var count: Int { builders.count }

    static func mockCase(at index: Int, now: Date = .now) -> MockCase {
        let builder = builders[((index % count) + count) % count]
        var made = builder(now)
        // 첫 이벤트 제목에 케이스 번호·이름 태깅 — 잠금화면에서 어느 케이스인지 식별.
        made = tagged(made, index: ((index % count) + count) % count)
        return made
    }

    private static let builders: [(Date) -> MockCase] = [
        fullBothColumns, empty, single, three, allDayOnly, oneDaySplit, longTitles, cjkEmoji,
    ]

    private static func tagged(_ mockCase: MockCase, index: Int) -> MockCase {
        guard let firstDay = mockCase.days.first, let firstEvent = firstDay.events.first else {
            return mockCase
        }
        let tagged = LiveEventItem(
            id: firstEvent.id,
            title: "[\(index + 1)/\(count) \(mockCase.name)] \(firstEvent.title)",
            startDate: firstEvent.startDate, endDate: firstEvent.endDate,
            timeText: firstEvent.timeText, calendarColorHex: firstEvent.calendarColorHex,
            isAllDay: firstEvent.isAllDay
        )
        var days = mockCase.days
        days[0] = LiveScheduleDay(
            id: firstDay.id, label: firstDay.label,
            events: [tagged] + firstDay.events.dropFirst()
        )
        return MockCase(name: mockCase.name, days: days)
    }

    // MARK: - 케이스

    private static func fullBothColumns(now: Date) -> MockCase {
        let today = day("오늘", offset: 0, now: now, events: [
            allDayItem("종일 워크샵", color: "#FF9500"),
            allDayItem("건강검진", color: "#FFCC00"),
            timedItem("팀 회의", offset: 0, minutesFromNow: 30, color: "#007AFF", now: now),
            timedItem("디자인 리뷰", offset: 0, minutesFromNow: 120, color: "#AF52DE", now: now),
            timedItem("저녁 약속", offset: 0, minutesFromNow: 240, color: "#FF2D55", now: now),
        ])
        let tomorrow = day("내일", offset: 1, now: now, events: [
            timedItem("월간 결산 보고", offset: 1, hour: 11, color: "#007AFF", now: now),
            timedItem("고객 미팅", offset: 1, hour: 14, color: "#AF52DE", now: now),
            timedItem("헬스", offset: 1, hour: 19, color: "#34C759", now: now),
        ])
        let dayAfter = day("모레", offset: 2, now: now, events: [
            timedItem("작업실 정리", offset: 2, hour: 10, color: "#FF6482", now: now),
            timedItem("데이터 백업", offset: 2, hour: 15, color: "#5856D6", now: now),
        ])
        let later = day("7/28 (화)", offset: 3, now: now, events: [
            timedItem("주간 리뷰", offset: 3, hour: 9, color: "#FF9500", now: now),
            timedItem("가족 저녁", offset: 3, hour: 18, color: "#34C759", now: now),
        ])
        return MockCase(name: "양쪽 꽉참", days: [today, tomorrow, dayAfter, later])
    }

    private static func empty(now: Date) -> MockCase {
        MockCase(name: "없음", days: [])
    }

    private static func single(now: Date) -> MockCase {
        MockCase(name: "1개", days: [
            day("오늘", offset: 0, now: now, events: [
                timedItem("혼자 있는 일정", offset: 0, minutesFromNow: 60, color: "#007AFF", now: now),
            ]),
        ])
    }

    private static func three(now: Date) -> MockCase {
        MockCase(name: "3개", days: [
            day("오늘", offset: 0, now: now, events: [
                timedItem("첫 번째", offset: 0, minutesFromNow: 30, color: "#007AFF", now: now),
                timedItem("두 번째", offset: 0, minutesFromNow: 90, color: "#AF52DE", now: now),
                timedItem("세 번째", offset: 0, minutesFromNow: 180, color: "#34C759", now: now),
            ]),
        ])
    }

    private static func allDayOnly(now: Date) -> MockCase {
        MockCase(name: "종일만", days: [
            day("오늘", offset: 0, now: now, events: [
                allDayItem("휴가", color: "#5AC8FA"),
                allDayItem("워크샵", color: "#FF9500"),
            ]),
            day("내일", offset: 1, now: now, events: [
                allDayItem("기념일", color: "#FF2D55"),
            ]),
            day("모레", offset: 2, now: now, events: [
                allDayItem("출장", color: "#5856D6"),
            ]),
        ])
    }

    private static func oneDaySplit(now: Date) -> MockCase {
        let events = (0..<7).map { index in
            timedItem("연속 일정 \(index + 1)", offset: 0, minutesFromNow: 30 + index * 60,
                      color: "#007AFF", now: now)
        }
        return MockCase(name: "한 날 연속분할", days: [day("오늘", offset: 0, now: now, events: events)])
    }

    private static func longTitles(now: Date) -> MockCase {
        MockCase(name: "긴 제목", days: [
            day("오늘", offset: 0, now: now, events: [
                timedItem("아주아주 길어서 한 줄에 절대 다 안 들어가는 일정 제목의 말줄임 확인",
                          offset: 0, minutesFromNow: 30, color: "#FF9500", now: now),
                allDayItem("종일인데도 제목이 길어서 캡슐 가운데 정렬과 말줄임이 어떻게 보이는지",
                           color: "#34C759"),
            ]),
            day("내일", offset: 1, now: now, events: [
                timedItem("내일도 긴 제목 하나 — 열 너비 대비 줄임표 위치 확인용 텍스트",
                          offset: 1, hour: 10, color: "#AF52DE", now: now),
            ]),
        ])
    }

    private static func cjkEmoji(now: Date) -> MockCase {
        MockCase(name: "CJK·이모지", days: [
            day("오늘", offset: 0, now: now, events: [
                allDayItem("🏝️ 休暇スタート", color: "#5AC8FA"),
                timedItem("工作坊及团队建设", offset: 0, minutesFromNow: 45, color: "#FF9500", now: now),
                timedItem("🎂 Birthday dinner", offset: 0, minutesFromNow: 150, color: "#FF2D55", now: now),
            ]),
            day("내일", offset: 1, now: now, events: [
                timedItem("月度结算报告", offset: 1, hour: 11, color: "#007AFF", now: now),
            ]),
        ])
    }

    // MARK: - 빌더

    private static func day(_ label: String, offset: Int, now: Date, events: [LiveEventItem]) -> LiveScheduleDay {
        LiveScheduleDay(id: "mock-\(offset)", label: label, events: events)
    }

    /// 시간 이벤트 — 오늘(offset 0)은 `minutesFromNow`로 지금 이후에, 다른 날은 절대 시각으로.
    private static func timedItem(
        _ title: String, offset: Int, minutesFromNow: Int = 0, hour: Int? = nil,
        color: String, now: Date
    ) -> LiveEventItem {
        let calendar = Calendar.current
        let dayStart = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) ?? now
        let start: Date
        if let hour, offset > 0 {
            start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart) ?? dayStart
        } else {
            start = now.addingTimeInterval(TimeInterval(minutesFromNow * 60))
        }
        let end = start.addingTimeInterval(3600)
        return LiveEventItem(
            id: UUID().uuidString, title: title, startDate: start, endDate: end,
            timeText: ScheduleTimeText.string(start: start, end: end, isAllDay: false, groupDate: dayStart),
            calendarColorHex: color, isAllDay: false
        )
    }

    private static func allDayItem(_ title: String, color: String) -> LiveEventItem {
        let now = Date()
        return LiveEventItem(
            id: UUID().uuidString, title: title, startDate: now, endDate: now,
            timeText: "", calendarColorHex: color, isAllDay: true
        )
    }
}

/// ⚠️ 임시 — LA 카드 위 ‹ › 탭으로 mock 케이스를 순환 전환한다.
/// `LiveActivityIntent`라 perform()은 메인 앱 프로세스에서 실행돼 떠 있는 LA를 직접 update한다.
struct ShiftMockScheduleCaseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Shift Mock Schedule Case"

    /// 이동 방향 — -1(이전 케이스) / +1(다음 케이스).
    @Parameter(title: "delta") var delta: Int

    init() {}

    init(delta: Int) {
        self.delta = delta
    }

    func perform() async throws -> some IntentResult {
        guard let activity = Activity<ScheduleLiveActivityAttributes>.activities.first else {
            return .result()
        }
        let count = MockScheduleLiveCases.count
        let stored = SharedAppGroup.defaults.integer(forKey: MockScheduleLiveCases.indexKey)
        let next = (((stored + delta) % count) + count) % count
        SharedAppGroup.defaults.set(next, forKey: MockScheduleLiveCases.indexKey)

        let mock = MockScheduleLiveCases.mockCase(at: next)
        var state = activity.content.state
        state.days = mock.days
        state.todayCount = mock.todayCount
        await activity.update(ActivityContent(state: state, staleDate: activity.content.staleDate))
        return .result()
    }
}
