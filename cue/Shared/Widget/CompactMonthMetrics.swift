//
//  CompactMonthMetrics.swift
//  cue / Shared
//

import UIKit

/// 좁은 월 격자(`CompactMonthGrid`)의 **행 최소 높이**.
///
/// ⚠️ 위젯 높이를 상수로 두지 않는다.
/// 예전엔 가장 좁은 기기(141pt)를 기준으로 "격자 몫"을 계산해 행 높이를 못 박았는데,
/// 실제 medium 위젯은 그보다 커서 큰 기기에서 격자만 쪼그라들고 카드 아래에 빈 자리가
/// 남았다(실기기에서 그랬다). 기기 높이는 시스템이 정하는 값이라 상수로 맞힐 수 없다.
///
/// 지금은 행이 **주어진 높이를 나눠 갖고**, 여기 값은 그 **바닥**으로만 쓴다 —
/// 좁은 기기에서 6주 달이 눌려 들어가는 하한이다. 위젯이 크면 행은 그만큼 늘어난다.
enum CompactMonthMetrics {

    /// 행이 아무리 눌려도 이보다 얇아지지 않는다 — 날짜 글자 + 점이 들어갈 최소치.
    ///
    /// 날짜 줄에서 **디센더 몫을 빼고** 점 자리를 잡는다. 숫자에는 디센더(g·y처럼 baseline
    /// 아래로 내려가는 획)가 없어 줄 상자 아래가 늘 비는데, 점은 그 자리를 쓴다.
    ///
    /// 이 절약이 없으면 행마다 4pt, 6주면 24pt가 더 필요해 좁은 기기에서 마지막 주가
    /// 잘린다(실기기에서 그랬다).
    static var minimumRowHeight: CGFloat {
        dayNumberLine - dayNumberDescender + dotSize
    }

    /// 날짜 숫자 위아래 여백 — 6주 달은 행이 얇아 여백부터 깎는다.
    static func dayNumberPadding(weekCount: Int) -> CGFloat {
        weekCount >= 6 ? 1 : Spacing.xxs
    }

    /// 날짜 글자의 디센더 높이 — 점이 앉는 빈 자리.
    static var dayNumberDescender: CGFloat {
        abs(UIFont.preferredFont(forTextStyle: .caption2, compatibleWith: compactTraits).descender)
    }


    /// 날짜 숫자 한 줄 높이 — 뷰가 `.caption2`로 그린다.
    ///
    /// 뷰도 `.dynamicTypeSize(.xSmall)`로 렌더를 고정하므로 추정 = 렌더가 유지된다
    /// (`MonthWidgetMetrics`와 같은 규칙).
    static var dayNumberLine: CGFloat { line(.caption2) }

    private static func line(_ style: UIFont.TextStyle) -> CGFloat {
        UIFont.preferredFont(forTextStyle: style, compatibleWith: compactTraits).lineHeight
    }

    private static let compactTraits = UITraitCollection(preferredContentSizeCategory: .extraSmall)

    /// 점 지름 — 뷰와 **같은 값**이어야 예산이 맞는다.
    static let dotSize: CGFloat = 3
}
