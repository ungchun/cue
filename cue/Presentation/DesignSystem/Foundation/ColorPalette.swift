//
//  ColorPalette.swift
//  cue / Presentation
//

import SwiftUI

/// 원시(primitive) 색 팔레트 — OKLCH로 작성한 raw 값.
///
/// **뷰에서 직접 사용하지 않는다.** 의미 있는 색은 `AppColor`(semantic 토큰)로 쓴다.
///
/// ⚠️ 중립 회색 + accent/danger는 브랜드 색이 정해지기 전의 **placeholder**다.
/// 브랜드 색이 정해지면 이 파일의 OKLCH 값만 교체하면 앱 전체가 따라온다.
enum ColorPalette {
    // 중립 (achromatic — chroma 0)
    static let neutral50 = Color.oklch(0.99, 0, 0)
    static let neutral100 = Color.oklch(0.97, 0, 0)
    static let neutral200 = Color.oklch(0.92, 0, 0)
    static let neutral300 = Color.oklch(0.86, 0, 0)
    static let neutral400 = Color.oklch(0.74, 0, 0)
    static let neutral500 = Color.oklch(0.62, 0, 0)
    static let neutral600 = Color.oklch(0.52, 0, 0)
    static let neutral700 = Color.oklch(0.42, 0, 0)
    static let neutral800 = Color.oklch(0.30, 0, 0)
    static let neutral900 = Color.oklch(0.22, 0, 0)
    static let neutral950 = Color.oklch(0.15, 0, 0)

    // accent (파랑 계열 placeholder, hue 255)
    static let accent400 = Color.oklch(0.72, 0.14, 255)
    static let accent500 = Color.oklch(0.62, 0.15, 255)
    static let accent600 = Color.oklch(0.52, 0.15, 255)

    // danger (빨강 계열 — 오류 상태, hue 27)
    static let danger400 = Color.oklch(0.66, 0.17, 27)
    static let danger500 = Color.oklch(0.58, 0.19, 27)
}
