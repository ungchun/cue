//
//  DayTimelineMetrics.swift
//  cue / Shared
//

import UIKit

/// 시간표 위젯 블록의 **치수**. 폭을 제목 길이에서 재는 게 핵심이다.
///
/// 왜 균등분할이 아닌가 — 24시간을 위젯 한 장(약 250pt)에 담으면 1시간이 10pt다. 일정이
/// 몰린 오전에는 겹침이 네 겹까지 가는데, 하루 열(100pt)을 4등분하면 25pt가 되어 제목이
/// 한 글자도 안 들어간다. 레퍼런스처럼 **제목이 필요한 만큼만 차지하고 옆 날짜 열까지
/// 넘어가게** 두면, 같은 공간에서 훨씬 많은 제목이 읽힌다.
enum DayTimelineMetrics {

    private static let compactTraits = UITraitCollection(preferredContentSizeCategory: .extraSmall)

    /// 블록 제목이 쓰는 폰트 — 뷰(`.font(.caption2)` + `.dynamicTypeSize(.xSmall)`)와 동기.
    static var titleFont: UIFont {
        UIFont.preferredFont(forTextStyle: .caption2, compatibleWith: compactTraits)
    }

    /// 블록 최소 높이 — 제목 한 줄이 들어갈 만큼. 30분 일정도 이만큼은 차지한다.
    static var minimumHeight: CGFloat { titleFont.lineHeight.rounded(.up) }

    /// 제목 앞 마커 한 변.
    static let markerSize: CGFloat = 5
    /// 마커 ↔ 제목 간격.
    static let markerGap: CGFloat = Spacing.xxs
    /// 블록 좌우 안쪽 여백(한쪽).
    static let horizontalPadding: CGFloat = 1.5

    /// 이 폭 미만이면 마커를 생략하고 제목만 그린다.
    ///
    /// 마커는 5pt + 간격이라 20pt짜리 블록에서는 폭의 40%를 먹는다. 그 대가로 제목이
    /// 말줄임표만 남으면 손해다 — 소속 색은 배경이 이미 말해주므로 마커를 뺀다.
    static let markerWidthThreshold: CGFloat = 40
    /// 인접 블록 사이 가로 틈.
    static let gap: CGFloat = 1

    /// 제목이 온전히 들어가는 블록 폭. 이보다 좁아지면 뷰가 말줄임으로 처리한다.
    static func preferredWidth(for item: WidgetCalendarItem) -> CGFloat {
        let title = (item.title as NSString)
            .size(withAttributes: [.font: titleFont]).width
        return (title + markerSize + markerGap + horizontalPadding * 2).rounded(.up)
    }

    /// 좁은 블록에서 뷰가 글자를 줄이는 하한 배율 — `.minimumScaleFactor`와 동기.
    /// 폭 임계값을 이 배율로 계산해야 "그릴 수 있다"는 판정과 실제 렌더가 일치한다.
    ///
    /// 0.55는 3일 위젯의 최악 조건에서 역산한 값이다: 하루 열 102pt에 여섯 겹이 쌓이면
    /// 한 칸이 17pt인데, 이보다 배율이 높으면 최소 폭이 그 위로 올라가 여섯 번째 블록이
    /// 통째로 `+N`으로 밀린다. 이 배율은 겹침이 깊은 구간에만 적용된다.
    static let minimumTitleScale: CGFloat = 0.55

    /// 마커·여백처럼 제목과 무관하게 고정으로 먹는 폭. 마커가 빠지는 좁은 블록 기준.
    private static var chrome: CGFloat { horizontalPadding * 2 }

    /// 이보다 좁으면 제목을 줄여도 두 글자가 안 들어간다 — `+N`으로 돌린다.
    /// 두 글자 기준: 축소된 글자 크기의 두 배(한글 기준 대략 정사각 글리프).
    static var minimumWidth: CGFloat {
        (chrome + titleFont.pointSize * minimumTitleScale * 2).rounded(.up)
    }

    /// 제목을 아예 빼고 색 막대만 남기는 폭 임계값.
    static var barOnlyWidth: CGFloat { minimumWidth }
}
