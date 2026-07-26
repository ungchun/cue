//
//  ScheduleLiveActivityAttributes.swift
//  cue / Shared
//

import ActivityKit
import Foundation

/// 일정 라이브 액티비티의 attributes.
///
/// `startedAt`은 ContentState `today`/`tomorrow`가 어느 시점 기준으로 잘렸는지 추적용 —
/// 시계가 다음 날로 넘어가면 "내일" 항목이 "오늘"이 되어야 하지만, 마이그레이션은 앱이
/// foreground일 때 `update`로만 일어난다. attributes에 박아두면 디버깅·migration 안전성 ↑.
///
/// 시스템 timer 표현(`Text(_:style: .relative)`)이 매 프레임 자동 갱신하므로 매초 update 금지.
struct ScheduleLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        /// 날짜순 day 묶음(오늘부터). 위젯이 2열에 들어가는 만큼만 그린다.
        var days: [LiveScheduleDay]
        /// 오늘 일정 수(종일 전부 + 종료 안 지난 시간 이벤트) — Dynamic Island 주간 캘린더
        /// 스트립 우상단 카운트용. 표시 truncation과 무관하게 정확하도록 앱에서 계산해 싣는다.
        /// 기본값 0 — 기존 ContentState 생성부 호환.
        var todayCount: Int = 0
        /// 잠금화면 월간 캘린더의 표시 월 오프셋(이번 달 = 0, ±12 클램프) — 셰브런 탭
        /// 인텐트가 갱신한다. 앱이 재게시하면 0으로 리셋(이번 달로 복귀).
        var calendarMonthOffset: Int = 0
        /// Dynamic Island 주간 스트립의 날짜별 일정 점(오늘 제외) — 각 날 이벤트 색.
        /// 기본값 빈 배열 — 기존 ContentState 생성부/전방 디코딩 호환.
        var weekEventDots: [LiveDayEventDots] = []
        /// 잠금화면 월간 캘린더(캘린더 함께 보기)의 날짜별 일정 점 — 표시 월 기준. 기본값 빈 배열.
        var monthEventDots: [LiveMonthDot] = []
        /// 잠금화면 월간 캘린더 표시를 설정 미러(App Group)와 무관하게 강제하는 오버라이드.
        /// nil이면 위젯이 설정 미러를 따른다(기존 동작). 온보딩 목업 게시가 true로 켜 —
        /// 설정을 건드리지 않고 이 LA 한정으로 캘린더를 보여준다(전역 상태 오염·원복 누락 없음).
        var showsCalendarOverride: Bool? = nil
    }

    let startedAt: Date
}

extension ScheduleLiveActivityAttributes.ContentState {
    /// 전방 호환 디코딩 — 앱 업데이트 전 게시된 활성 LA의 옛 상태에 `todayCount`·
    /// `calendarMonthOffset`이 없어도 재포착(sync) 시 기본값으로 채워 디코딩이 실패하지 않게 한다.
    /// (extension에 두어 본문의 memberwise init 합성을 유지 — AppSettings와 같은 방식.)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        days = try container.decode([LiveScheduleDay].self, forKey: .days)
        todayCount = try container.decodeIfPresent(Int.self, forKey: .todayCount) ?? 0
        calendarMonthOffset = try container.decodeIfPresent(Int.self, forKey: .calendarMonthOffset) ?? 0
        weekEventDots = try container.decodeIfPresent([LiveDayEventDots].self, forKey: .weekEventDots) ?? []
        monthEventDots = try container.decodeIfPresent([LiveMonthDot].self, forKey: .monthEventDots) ?? []
        showsCalendarOverride = try container.decodeIfPresent(Bool.self, forKey: .showsCalendarOverride)
    }
}
