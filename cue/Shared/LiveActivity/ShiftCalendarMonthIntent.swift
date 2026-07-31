//
//  ShiftCalendarMonthIntent.swift
//  cue / Shared
//

@preconcurrency import ActivityKit
import AppIntents
import Foundation

// MARK: - 타깃 멤버십
//
// 위젯이 `Button(intent:)`로 참조하므로 **앱 + 익스텐션 양쪽**에 컴파일된다(pbxproj exception).
// 앱 전용 타입은 참조하지 않고 시스템 프레임워크(ActivityKit)만으로 자급자족한다.
// (`MonthCalendarGrid`도 양쪽 타깃에 컴파일되는 공유 타입이라 참조 가능.)
//
// `LiveActivityIntent`라 perform()은 **메인 앱 프로세스**에서 실행된다 — 켜져 있는 LA의
// ContentState를 직접 update할 수 있다.

/// LA 월간 캘린더 셰브런 탭 — 표시 월을 앞뒤로 한 달 이동한다(±12개월 클램프).
///
/// 대상 LA를 raw 문자열로 구분한다(AppEnum 보일러플레이트 대신 — FocusAlarmAdvanceIntent의
/// `nextPhaseRaw` 전례). 메모·일정 LA가 동시에 떠 있어도 탭한 쪽만 움직인다.
struct ShiftCalendarMonthIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Shift Calendar Month"
    /// 단축어 갤러리에 노출할 이유가 없다 — LA 셰브런 전용(`ShiftWidgetRangeIntent` 전례).
    static let isDiscoverable = false

    /// 어느 LA의 캘린더인지 — `memoTarget` 또는 `scheduleTarget`.
    @Parameter(title: "target") var targetRaw: String
    /// 이동 방향 — -1(이전 달) / +1(다음 달).
    @Parameter(title: "delta") var delta: Int

    static let memoTarget = "memo"
    static let scheduleTarget = "schedule"
    static let reminderTarget = "reminder"

    init() {}

    init(targetRaw: String, delta: Int) {
        self.targetRaw = targetRaw
        self.delta = delta
    }

    func perform() async throws -> some IntentResult {
        switch targetRaw {
        case Self.memoTarget: await shiftMemo()
        case Self.scheduleTarget: await shiftSchedule()
        case Self.reminderTarget: await shiftReminder()
        default: break
        }
        return .result()
    }

    private func shiftMemo() async {
        guard let activity = Activity<MemoLiveActivityAttributes>.liveActivity else { return }
        var state = activity.content.state
        state.calendarMonthOffset = MonthCalendarGrid.clampedOffset(state.calendarMonthOffset + delta)
        // 이동한 달의 일정 점을 그 자리에서 재조회해 함께 갱신 — 어느 달로 넘겨도 점이 뜬다.
        state.monthEventDots = CalendarMonthDots.dots(monthOffset: state.calendarMonthOffset)
        // staleDate는 기존 값 보존 — 월 이동이 신선도 정책을 바꾸면 안 된다.
        await activity.update(ActivityContent(state: state, staleDate: activity.content.staleDate))
        logShift()
    }

    private func shiftSchedule() async {
        guard let activity = Activity<ScheduleLiveActivityAttributes>.liveActivity else { return }
        var state = activity.content.state
        state.calendarMonthOffset = MonthCalendarGrid.clampedOffset(state.calendarMonthOffset + delta)
        state.monthEventDots = CalendarMonthDots.dots(monthOffset: state.calendarMonthOffset)
        await activity.update(ActivityContent(state: state, staleDate: activity.content.staleDate))
        logShift()
    }

    private func shiftReminder() async {
        guard let activity = Activity<ReminderLiveActivityAttributes>.liveActivity else { return }
        var state = activity.content.state
        state.calendarMonthOffset = MonthCalendarGrid.clampedOffset(state.calendarMonthOffset + delta)
        state.monthEventDots = CalendarMonthDots.dots(monthOffset: state.calendarMonthOffset)
        await activity.update(ActivityContent(state: state, staleDate: activity.content.staleDate))
        logShift()
    }

    /// LA 업데이트가 실제로 일어난 경우에만 호출 — `targetRaw`가 그대로 kind가 된다.
    private func logShift() {
        LiveActivityAnalyticsBridge.log?(
            "live_calendar_shifted",
            ["kind": targetRaw, "direction": delta < 0 ? "previous" : "next"]
        )
    }
}
