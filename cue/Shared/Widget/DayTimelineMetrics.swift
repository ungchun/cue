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
    static let markerSize: CGFloat = 5
    /// 마커 ↔ 제목 간격.
    static let markerGap: CGFloat = Spacing.xxs
    /// 블록 좌우 안쪽 여백(한쪽).
    static let horizontalPadding: CGFloat = 1.5

    /// 블록 왼쪽 가장자리의 색 막대 폭 — 뷰(`WidgetCalendarTheme.markerBarWidth`)와 동기.
    /// 제목이 쓸 수 있는 폭에서 먼저 빠지므로 예산에도 반영해야 한다.
    static let leadingBarWidth: CGFloat = 3

    /// 인접 블록 사이 가로 틈.
    static let gap: CGFloat = 1

    /// 제목이 온전히 들어가는 블록 폭. 이보다 좁아지면 뷰가 말줄임으로 처리한다.
    static func preferredWidth(for item: WidgetCalendarItem) -> CGFloat {
        // 뷰가 글자를 `titleScale`로 줄여 그리므로 측정값에도 같은 배율을 곱한다 —
        // 안 그러면 실제보다 넓게 잡아 블록 오른쪽에 빈 공간이 남는다.
        let title = (item.title as NSString)
            .size(withAttributes: [.font: titleFont]).width * titleScale
        return (title + chrome(for: item.kind)).rounded(.up)
    }

    /// 제목과 무관하게 고정으로 먹는 폭 — **종류마다 다르다.**
    ///
    /// 일정은 왼쪽 색 막대가 서고 마커가 없다. 할일은 반대로 막대 없이 동그라미만 단다.
    /// 뷰가 그렇게 그리므로 예산도 같이 갈라져야 어느 쪽도 제목이 밀리지 않는다.
    private static func chrome(for kind: WidgetCalendarItem.Kind) -> CGFloat {
        let leading = kind == .reminder ? markerSize + markerGap : leadingBarWidth
        return leading + horizontalPadding * 2
    }

    /// 폭 하한을 잡을 때 쓰는 기준 — **좁은 쪽**(일정)이다.
    ///
    /// 넓은 쪽(할일)으로 잡으면 하한이 그만큼 올라가, 겹침이 깊은 오전 시간대에서
    /// 일정까지 무더기로 버려진다(실기기에서 5겹이면 예산 20pt 대 하한 23pt로 전부 탈락).
    /// 할일은 동그라미가 조금 더 먹지만 제목이 한 글자 짧아질 뿐, 통째로 사라지진 않는다.
    private static var chrome: CGFloat { chrome(for: .timedEvent) }

    /// 제목 한 글자가 들어가는 폭.
    ///
    /// 겹침이 깊어도 글자 크기는 끝까지 같으므로(`titleScale` 고정), 하한도 **그 크기**로
    /// 잡아야 "그릴 수 있다"는 판정과 렌더가 일치한다.
    /// 말줄임표 몫은 더하지 않는다 — 뷰가 `...`를 만들지 않고 끝에서 잘라내므로,
    /// 그만큼을 요구하면 한 글자는 들어갈 칸까지 색 막대로 밀려난다.
    static var minimumWidth: CGFloat {
        (chrome + titleFont.pointSize * titleScale).rounded(.up)
    }

    /// 제목을 아예 빼고 색 막대만 남기는 폭 임계값.
    static var barOnlyWidth: CGFloat { minimumWidth }
}
