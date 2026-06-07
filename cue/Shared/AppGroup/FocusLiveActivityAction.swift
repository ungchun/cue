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
enum FocusLiveActivityAction: String, Codable, Sendable, Equatable {
    case pause
    case resume
    case end
}
