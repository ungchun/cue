//
//  FocusLiveActivityAttributes.swift
//  cue / Shared
//

import ActivityKit
import Foundation

/// 집중 세션 라이브 액티비티의 attributes — 시작 후 불변 필드 + 변경 가능 ContentState 분리.
///
/// 세션 동안 변하지 않는 정보(`sessionID`·`sessionTitle`·`startedAt`)는 attributes에.
/// 진행 상태(`phase`·`phaseEndDate`·`pauseTime`)는 모두 ContentState로 — 시스템 타이머가
/// 이 둘만으로 매 프레임 자동 갱신하므로 앱은 transition(시작/일시정지/재개/페이즈 전환)
/// 시점에만 `update`를 보낸다. 매초 update 금지.
///
/// schema migration 안전성: ContentState 필드는 **추가만 허용, 제거 금지**. 위젯 런타임이
/// 앱과 다른 빌드 버전을 디코드할 수 있어 누락된 필드가 있으면 Activity가 조용히 사라진다.
struct FocusLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var phase: LiveFocusPhase
        /// Phase 시작 시각 — widget `Text(timerInterval:)`의 lowerBound로 사용. 매 프레임 변동하는
        /// `.now`를 lowerBound로 두면 interval 자체가 매번 재계산돼 `pauseTime` 효과가 무력화된다.
        /// pause 동안엔 그대로, resume·phase 전환 시 갱신.
        var phaseStartDate: Date
        var phaseEndDate: Date
        var pauseTime: Date?
    }

    let sessionID: UUID
    let sessionTitle: String
    let startedAt: Date
}
