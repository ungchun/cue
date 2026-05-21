//
//  AppColor.swift
//  cue / Presentation
//

import SwiftUI
import UIKit

/// 의미(semantic) 색 토큰 — **뷰는 이것만 사용한다.**
///
/// 각 토큰은 라이트/다크 모드에 따라 자동 해석된다.
/// 팔레트를 바꾸려면 `ColorPalette`만 수정하면 앱 전체가 따라온다.
///
/// 사용: `.foregroundStyle(AppColor.textPrimary)`, `.background(AppColor.background)`.
enum AppColor {
    // 배경·표면
    static let background = Color.dynamic(light: ColorPalette.neutral50, dark: ColorPalette.neutral950)
    static let surface = Color.dynamic(light: ColorPalette.neutral50, dark: ColorPalette.neutral900)
    static let surfaceSecondary = Color.dynamic(light: ColorPalette.neutral100, dark: ColorPalette.neutral800)

    // 텍스트
    static let textPrimary = Color.dynamic(light: ColorPalette.neutral900, dark: ColorPalette.neutral100)
    static let textSecondary = Color.dynamic(light: ColorPalette.neutral600, dark: ColorPalette.neutral400)
    static let textTertiary = Color.dynamic(light: ColorPalette.neutral500, dark: ColorPalette.neutral500)

    // 강조
    static let accent = Color.dynamic(light: ColorPalette.accent500, dark: ColorPalette.accent400)
    /// accent 위에 올라가는 텍스트·아이콘 색
    static let onAccent = ColorPalette.neutral50

    // 경계
    static let border = Color.dynamic(light: ColorPalette.neutral200, dark: ColorPalette.neutral800)

    // 상태
    static let danger = Color.dynamic(light: ColorPalette.danger500, dark: ColorPalette.danger400)
}

extension Color {
    /// 라이트/다크 모드에 따라 두 색 중 하나로 해석되는 동적 색.
    static func dynamic(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}
