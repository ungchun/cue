//
//  FocusLiveActivityAction.swift
//  cue / Shared
//

import Foundation

/// 잠금화면·Dynamic Island의 라이브 액티비티 버튼이 발행하는 사용자 액션.
///
/// `pause`·`resume`을 분리해두는 이유: App Intent 측에서 현재 LA state를 확인해 토글로
/// 처리하지만, 큐에는 **결정된 의도**가 기록되어야 메인 앱이 drain 시점에 상태와 무관하게
/// 그대로 실행할 수 있다(race 회피).
///
/// `pause`/`resume`은 **누른 시각**(`at`)을 함께 싣는다 — 메인 앱이 drain하는 시점은 버튼을
/// 누른 시점보다 늦을 수 있어, 그 사이 흐른 시간만큼 카운트다운이 새는 걸 막으려면 누른
/// 시각 기준으로 정지/재개를 적용해야 한다(시각은 App Group `UserDefaults`에 JSON으로 보존).
enum FocusLiveActivityAction: Codable, Sendable, Equatable {
    case pause(at: Date)
    case resume(at: Date)
    case end
}
