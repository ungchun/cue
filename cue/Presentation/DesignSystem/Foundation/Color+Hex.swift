//
//  Color+Hex.swift
//  cue / Presentation
//

import SwiftUI

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
}
