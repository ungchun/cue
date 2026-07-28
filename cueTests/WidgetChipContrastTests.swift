//
//  WidgetChipContrastTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 종일 일정 칩은 캘린더 색으로 **꽉 채우므로**, 그 위 글자색을 배경 밝기에 따라
/// 검정/흰색으로 갈라야 라이트·다크 양쪽에서 읽힌다(칩 배경은 외부 데이터 색이라
/// 시스템 다크 대응이 자동으로 되지 않는다). 그 판정 로직 검증.
struct WidgetChipContrastTests {

    @Test func whiteBackgroundGetsDarkText() {
        #expect(WidgetChipContrast.prefersDarkText(onHex: "#FFFFFF"))
    }

    @Test func blackBackgroundGetsLightText() {
        #expect(!WidgetChipContrast.prefersDarkText(onHex: "#000000"))
    }

    @Test func pastelCalendarColorsGetDarkText() {
        // 레퍼런스 스크린샷의 종일 칩 색들 — 연분홍·연노랑·연하늘. 모두 검정 글자로 읽힌다.
        #expect(WidgetChipContrast.prefersDarkText(onHex: "#F7C4CB"))
        #expect(WidgetChipContrast.prefersDarkText(onHex: "#F2D34B"))
        #expect(WidgetChipContrast.prefersDarkText(onHex: "#B7E4E4"))
    }

    @Test func saturatedDarkCalendarColorsGetLightText() {
        #expect(!WidgetChipContrast.prefersDarkText(onHex: "#1D3557"))
        #expect(!WidgetChipContrast.prefersDarkText(onHex: "#8E1B1B"))
    }

    @Test func greenIsBrightEnoughForDarkTextButBlueIsNot() {
        // 휘도는 채널마다 가중치가 달라(녹 0.72 / 청 0.07) 같은 채도라도 갈린다 —
        // 단순 평균이 아니라 상대휘도로 계산하는지 확인하는 회귀 테스트.
        #expect(WidgetChipContrast.prefersDarkText(onHex: "#00FF00"))
        #expect(!WidgetChipContrast.prefersDarkText(onHex: "#0000FF"))
    }

    @Test func missingOrMalformedHexFallsBackToLightText() {
        // 색이 없으면 뷰가 시스템 accent(진한 파랑 계열)로 폴백하므로 흰 글자가 맞다.
        #expect(!WidgetChipContrast.prefersDarkText(onHex: nil))
        #expect(!WidgetChipContrast.prefersDarkText(onHex: "not-a-color"))
        #expect(!WidgetChipContrast.prefersDarkText(onHex: "#FFF"))
    }
}
