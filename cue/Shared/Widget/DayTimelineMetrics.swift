//
//  DayTimelineMetrics.swift
//  cue / Shared
//

import UIKit

/// 시간표 위젯 블록의 **치수** — 폰트·마커·여백처럼 그리는 데 필요한 값들.
///
/// 블록의 가로 폭과 위치는 여기서 정하지 않는다. 그건 컬럼 패킹의 몫이다
/// (→ `DayTimelineLayout`). 이 타입이 답하는 건 "그 폭에 제목이 들어가는가"뿐이다.
enum DayTimelineMetrics {

    private static let compactTraits = UITraitCollection(preferredContentSizeCategory: .extraSmall)

    /// 블록 제목이 쓰는 폰트 — 뷰(`.font(.caption2)` + `.dynamicTypeSize(.xSmall)`)와 동기.
    static var titleFont: UIFont {
        UIFont.preferredFont(forTextStyle: .caption2, compatibleWith: compactTraits)
    }

    /// 제목 글자 축소율 — 뷰의 `.scaleEffect`와 동기.
    ///
    /// `caption2`가 SwiftUI 텍스트 스타일 램프의 바닥이라, 그보다 작게 하려면 이 방법뿐이다.
    /// 폭·높이 예산도 **이 배율을 곱한 크기**로 재야 판정과 렌더가 어긋나지 않는다.
    static let titleScale: CGFloat = 0.78

    /// 축소가 반영된 실제 제목 줄높이.
    private static var scaledLineHeight: CGFloat { titleFont.lineHeight * titleScale }

    /// 블록 최소 높이 — 제목 한 줄이 들어갈 만큼. 30분 일정도 이만큼은 차지한다.
    static var minimumHeight: CGFloat { scaledLineHeight.rounded(.up) }

    /// 제목 앞 마커 한 변.
    static let markerSize: CGFloat = 4
    /// **속이 찬** 마커의 지름 — 빈 원보다 한 단계 작다.
    /// 같은 지름이어도 채운 원이 커 보여서 눈에 맞춘다. 차지하는 자리는 그대로다.
    static let filledMarkerSize: CGFloat = 3.5
    /// 마커 ↔ 제목 간격.
    static let markerGap: CGFloat = Spacing.xxs
    /// 블록 좌우 안쪽 여백(한쪽).
    static let horizontalPadding: CGFloat = 1.5

    /// 블록 왼쪽 가장자리의 색 막대 폭.
    ///
    /// 월 위젯의 막대(`WidgetCalendarTheme.markerBarWidth`)와 따로 둔다 — 시간표 블록은
    /// 폭이 20pt까지 좁아질 수 있어, 3pt면 블록의 15%를 막대가 차지해 제목 자리를 뺏는다.
    static let leadingBarWidth: CGFloat = 2

    /// 인접 블록 사이 가로 틈.
    static let gap: CGFloat = 1

    /// 제목을 아예 빼고 색 막대만 남기는 폭 임계값.
    ///
    /// 폭은 컬럼 패킹이 정하므로(→ `DayTimelineLayout`) 예산 계산은 없다. 여기서 답할 건
    /// 하나뿐이다 — **주어진 폭에 제목 한 글자가 들어가는가.**
    /// 왼쪽에 서는 것(일정은 색 막대, 할일은 동그라미) 중 넓은 쪽을 기준으로 잡아,
    /// 어느 종류든 글자가 잘려 나오지 않게 한다.
    static var barOnlyWidth: CGFloat {
        let leading = max(leadingBarWidth, markerSize + markerGap)
        return (leading + horizontalPadding * 2 + titleFont.pointSize * titleScale).rounded(.up)
    }
}
