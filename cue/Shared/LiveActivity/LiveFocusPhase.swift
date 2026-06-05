//
//  LiveFocusPhase.swift
//  cue / Domain
//

import Foundation

/// 라이브 액티비티 위에서 표현되는 집중 세션의 단계. Domain 본체의 `FocusPhase`와
/// 별개로 두는 이유는 **표시 schema 진화를 도메인 진화로부터 격리**하기 위해서.
/// ContentState로 직렬화되며, 위젯 런타임이 앱과 다른 빌드 버전을 디코드할 수 있으니
/// 필드(case) **추가만 허용·제거 금지** 원칙으로 관리한다.
enum LiveFocusPhase: String, Codable, Hashable, Sendable {
    case focus
    case breakTime
    case completed
}
