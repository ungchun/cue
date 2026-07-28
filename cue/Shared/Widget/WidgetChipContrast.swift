//
//  WidgetChipContrast.swift
//  cue / Shared
//

import Foundation

/// 종일 일정 칩 위 글자색 판정 — 배경이 캘린더 색으로 **꽉 채워지기** 때문에 필요하다.
///
/// 시스템 시맨틱 컬러(`.primary`)는 라이트/다크에 맞춰 검정↔흰색으로 뒤집히지만, 칩 배경은
/// 외부 데이터(EventKit 캘린더 색)라 모드에 따라 바뀌지 않는다. 그래서 다크 모드의 `.primary`
/// (흰색)를 연분홍 칩 위에 얹으면 읽히지 않는다 — 배경 밝기로 직접 갈라야 한다.
///
/// 판정은 WCAG 상대휘도. 단순 RGB 평균이 아니라 채널 가중치(적 0.2126·녹 0.7152·청 0.0722)를
/// 쓰는 이유는 같은 채도라도 녹색은 밝고 파랑은 어둡게 **보이기** 때문이다.
enum WidgetChipContrast {

    /// 상대휘도 임계값. 0.5가 아니라 조금 낮춰 잡는다 — 중간 밝기 파스텔에서는 검정 글자가
    /// 흰 글자보다 대비가 크고, EventKit 기본 캘린더 색이 대부분 이 구간에 몰려 있다.
    private static let threshold = 0.45

    /// 이 배경색 위에 **검정 계열** 글자를 얹어야 하면 `true`, 흰 계열이면 `false`.
    /// 색이 없거나 파싱 실패면 뷰가 시스템 accent(진한 파랑 계열)로 폴백하므로 `false`.
    static func prefersDarkText(onHex hex: String?) -> Bool {
        guard let luminance = relativeLuminance(of: hex) else { return false }
        return luminance > threshold
    }

    /// `"#RRGGBB"` / `"RRGGBB"` → WCAG 상대휘도(0...1). 포맷이 아니면 `nil`.
    private static func relativeLuminance(of hex: String?) -> Double? {
        guard var text = hex else { return nil }
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }

        let channels = [(value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff]
            .map { linearized(Double($0) / 255) }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }

    /// sRGB 감마 해제 — 저장된 채널값은 감마 보정돼 있어 그대로 더하면 밝기가 왜곡된다.
    private static func linearized(_ channel: Double) -> Double {
        channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }
}
