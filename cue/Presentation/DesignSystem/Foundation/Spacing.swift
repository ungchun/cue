//
//  Spacing.swift
//  cue / Presentation
//

import CoreGraphics

/// 간격 토큰 — 4/8pt 그리드. 패딩·요소 간 간격은 이 값만 사용한다.
///
/// 사용: `.padding(Spacing.md)`.
enum Spacing {
    static let zero: CGFloat = 0
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let smd: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}
