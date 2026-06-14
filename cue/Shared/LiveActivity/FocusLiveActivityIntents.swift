//
//  FocusLiveActivityIntents.swift
//  cue / Shared
//

import ActivityKit
import AppIntents
import Foundation

// MARK: - 타깃 멤버십 (회귀 방지)
//
// `LiveActivityIntent`의 `perform()`은 **메인 앱 프로세스**에서 실행된다(시스템 보장).
// 따라서 이 파일은 반드시 **앱 타깃(`cue`)에 컴파일**돼 있어야 perform()이 실행된다 —
// 위젯 익스텐션에만 들어 있으면 버튼을 눌러도 perform()이 아예 호출되지 않아 정지/종료가
// 무반응이 된다(과거 증상). 동시에 위젯이 `Button(intent:)`에서 타입을 참조하려면 익스텐션
// 타깃에도 있어야 한다. 그래서 이 파일은 `cue/Shared/`에 두어 앱 타깃 기본 멤버로 두고,
// pbxproj의 exception set으로 `cueLiveActivityExtension` 타깃에도 추가해 **양쪽 모두**에
// 컴파일되게 한다(다른 Shared/LiveActivity 파일들과 동일 패턴). 한쪽으로 옮기지 말 것.

/// 잠금화면·Dynamic Island의 일시정지/재개 버튼이 발행하는 App Intent.
///
/// **동작 정책 — 즉시 피드백 + 사후 동기화**:
/// 1. 현재 Activity의 `pauseTime`을 보고 `pause`/`resume`을 결정해 큐에 enqueue.
/// 2. 잠금 상태에서도 시각 피드백을 주기 위해 LA `update`로 `pauseTime`만 즉시 토글.
///    `phaseStartDate`·`phaseEndDate`의 보정은 **메인 앱**이 drain 시 ViewModel.pause/resume
///    안에서 정확하게 다시 잡는다(앱 active 시점에 자연 수렴).
/// 3. perform()은 가벼운 update만 — race window를 줄이고 LA 상태 일관성은 결국
///    메인 앱의 ViewModel 호출 결과로 결정된다.
struct PauseResumeFocusIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "일시정지/재개"

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
    static let title: LocalizedStringResource = "집중 종료"

    init() {}

    func perform() async throws -> some IntentResult {
        FocusLiveActivityActionQueue.shared.enqueue(.end)
        if let activity = Activity<FocusLiveActivityAttributes>.activities.first {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}
