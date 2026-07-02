//
//  SettingsEnums+UI.swift
//  cue / Presentation
//

import SwiftUI
import UIKit

/// 설정 enum들의 화면 표시용 확장(레이블·폰트 매핑). Domain은 UI를 모르므로 여기 둔다.

extension MemoTextSize {
    /// 설정 Picker 레이블.
    var label: String {
        switch self {
        case .small: "작게"
        case .medium: "보통"
        case .large: "크게"
        }
    }

    /// 메모 입력 화면 글꼴의 텍스트 스타일 — 디자인 시스템 규칙대로 고정 크기 대신 텍스트 스타일을
    /// 쓴다(`.largeTitle`이 상한). 기본 `.large`가 현재 동작(largeTitle)을 유지한다.
    var inputTextStyle: UIFont.TextStyle {
        switch self {
        case .small: .title2
        case .medium: .title1
        case .large: .largeTitle
        }
    }
}
