//
//  Color+OKLCH.swift
//  cue / Presentation
//

import Foundation
import SwiftUI

extension Color {
    /// OKLCH 색을 sRGB `Color`로 변환한다.
    ///
    /// iOS는 OKLCH를 네이티브로 지원하지 않으므로(SwiftUI `Color`는 sRGB/P3만)
    /// OKLCH → OKLab → linear sRGB → 감마 인코딩 순으로 직접 변환한다.
    /// sRGB 색역을 벗어나는 값은 0...1로 클램프한다.
    ///
    /// - Parameters:
    ///   - l: Lightness, 0...1 (perceptual 명도)
    ///   - c: Chroma, 0...~0.4 (채도)
    ///   - h: Hue, 0...360 (도)
    ///   - opacity: 불투명도, 0...1
    static func oklch(_ l: Double, _ c: Double, _ h: Double, opacity: Double = 1) -> Color {
        // 1. OKLCH → OKLab (극좌표 → 직교좌표)
        let radians = h * .pi / 180
        let a = c * cos(radians)
        let b = c * sin(radians)

        // 2. OKLab → LMS' (비선형 LMS)
        let lPrime = l + 0.3963377774 * a + 0.2158037573 * b
        let mPrime = l - 0.1055613458 * a - 0.0638541728 * b
        let sPrime = l - 0.0894841775 * a - 1.2914855480 * b

        // 3. 세제곱
        let lms = (l: lPrime * lPrime * lPrime,
                   m: mPrime * mPrime * mPrime,
                   s: sPrime * sPrime * sPrime)

        // 4. LMS → linear sRGB
        let redLinear = 4.0767416621 * lms.l - 3.3077115913 * lms.m + 0.2309699292 * lms.s
        let greenLinear = -1.2684380046 * lms.l + 2.6097574011 * lms.m - 0.3413193965 * lms.s
        let blueLinear = -0.0041960863 * lms.l - 0.7034186147 * lms.m + 1.7076147010 * lms.s

        // 5 + 6. 색역 클램프 후 sRGB 감마 인코딩
        return Color(
            .sRGB,
            red: gammaEncodedSRGB(redLinear),
            green: gammaEncodedSRGB(greenLinear),
            blue: gammaEncodedSRGB(blueLinear),
            opacity: opacity
        )
    }

    /// linear sRGB 성분 → 감마 인코딩된 sRGB 성분. 0...1로 클램프한다.
    private static func gammaEncodedSRGB(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        if clamped <= 0.0031308 {
            return 12.92 * clamped
        }
        return 1.055 * pow(clamped, 1 / 2.4) - 0.055
    }
}
