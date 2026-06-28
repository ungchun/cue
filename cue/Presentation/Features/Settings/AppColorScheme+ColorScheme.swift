//
//  AppColorScheme+ColorScheme.swift
//  cue / Presentation
//

import SwiftUI

/// 도메인 설정값(`AppColorScheme`)을 SwiftUI의 `ColorScheme?`로 옮긴다.
/// Domain은 SwiftUI를 모르므로 이 매핑은 Presentation 계층에 둔다.
/// `.system`은 `nil` — 시스템 설정을 그대로 따른다(강제 고정 안 함).
extension AppColorScheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// 설정 화면 Picker에 표시할 한글 레이블.
    var label: String {
        switch self {
        case .system: "시스템"
        case .light: "라이트"
        case .dark: "다크"
        }
    }
}
