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
        var today: [LiveEventItem]
        var tomorrow: [LiveEventItem]
    }

    let startedAt: Date
}
