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
    }

    let startedAt: Date
}
