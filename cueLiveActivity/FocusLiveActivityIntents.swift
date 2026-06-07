//
//  FocusLiveActivityIntents.swift
//  cueLiveActivity
//

import ActivityKit
import AppIntents
import Foundation

/// 잠금화면·Dynamic Island의 일시정지/재개 버튼이 발행하는 App Intent.
///
/// **동작 정책 — 즉시 피드백 + 사후 동기화**:
/// 1. 현재 Activity의 `pauseTime`을 보고 `pause`/`resume`을 결정해 큐에 enqueue.
/// 2. 잠금 상태에서도 시각 피드백을 주기 위해 LA `update`로 `pauseTime`만 즉시 토글.
///    `phaseStartDate`·`phaseEndDate`의 보정은 **메인 앱**이 drain 시 ViewModel.pause/resume
///    안에서 정확하게 다시 잡는다(앱 active 시점에 자연 수렴).
/// 3. App Intent process는 가벼운 update만 — race window를 줄이고 LA 상태 일관성은 결국
///    메인 앱의 ViewModel 호출 결과로 결정된다.
struct PauseResumeFocusIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "일시정지/재개"

    init() {}

    func perform() async throws -> some IntentResult {
        guard let activity = Activity<FocusLiveActivityAttributes>.activities.first else {
            return .result()
        }
        let state = activity.content.state
        let action: FocusLiveActivityAction = state.pauseTime == nil ? .pause : .resume
        FocusLiveActivityActionQueue.shared.enqueue(action)

        // 즉시 피드백 — pauseTime만 토글. widget이 정적 텍스트로 freeze/dynamic 분기.
        var newState = state
        newState.pauseTime = (state.pauseTime == nil) ? .now : nil
        let content = ActivityContent(
            state: newState,
            staleDate: state.phaseEndDate.addingTimeInterval(30)
        )
        await activity.update(content)

        return .result()
    }
}

/// 잠금화면·Dynamic Island의 종료 버튼이 발행하는 App Intent.
///
/// LA를 즉시 `.immediate` dismiss + 큐에 `.end` enqueue. 메인 앱은 다음 active 시점에
/// drain하여 `FocusViewModel.stopSession()`을 호출 — 진행 중이던 세션을 정리한다.
struct EndFocusIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "집중 종료"

    init() {}

    func perform() async throws -> some IntentResult {
        FocusLiveActivityActionQueue.shared.enqueue(.end)
        if let activity = Activity<FocusLiveActivityAttributes>.activities.first {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}
