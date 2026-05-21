//
//  Typography.swift
//  cue / Presentation
//

import SwiftUI

/// 타이포그래피 토큰 — Apple 시스템 텍스트 스타일 위에 의미 이름을 매핑한다.
///
/// 시스템 텍스트 스타일을 기반으로 하므로 **Dynamic Type**(접근성 글자 크기)을
/// 자동으로 따라간다. 고정 크기 `.system(size:)`는 접근성을 깨므로 쓰지 않는다.
///
/// 사용: `.font(AppFont.bodyLarge)`.
enum AppFont {
    /// 화면 최상단 큰 제목
    static let displayLarge = Font.largeTitle.weight(.bold)
    /// 섹션 제목
    static let titleLarge = Font.title2.weight(.semibold)
    /// 하위 제목
    static let titleMedium = Font.title3.weight(.semibold)
    /// 강조 본문 (행 헤더 등)
    static let headline = Font.headline
    /// 기본 본문
    static let bodyLarge = Font.body
    /// 보조 본문
    static let bodySmall = Font.callout
    /// 캡션
    static let caption = Font.caption
    /// 가장 작은 캡션
    static let captionSmall = Font.caption2
}
