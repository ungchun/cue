//
//  Color+Hex.swift
//  cue / Presentation
//

import SwiftUI
import UIKit

extension Color {
    /// 외부 데이터(EventKit 캘린더 색 등)에서 받은 "#RRGGBB" 또는 "RRGGBB" hex 문자열을 `Color`로.
    /// 잘못된 포맷이면 `nil` — 호출자가 fallback을 정한다.
    ///
    /// 주의: 이 이니셜라이저는 **외부 데이터** 표현 전용이다. 디자인 색은 cue 규칙대로
    /// Apple 시스템 컬러(`.primary`/`.secondary`/`.tint` 등)와 `AccentColor` 자산만 쓴다.
    init?(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xff) / 255
        let g = Double((value >> 8) & 0xff) / 255
        let b = Double(value & 0xff) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// 사용자가 ColorPicker로 고른 임의 색을 저장 가능한 "#RRGGBB" 문자열로 환원한다.
    /// SwiftUI Color → UIColor 경유로 sRGB 컴포넌트를 추출하므로 P3/HDR 색은 손실될 수 있음.
    /// alpha는 버린다 — 세션 색은 불투명이 디자인.
    var hexString: String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let clamp: (CGFloat) -> Int = { Int((max(0, min(1, $0)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", clamp(r), clamp(g), clamp(b))
    }
}
