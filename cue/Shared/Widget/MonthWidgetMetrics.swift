//
//  MonthWidgetMetrics.swift
//  cue / Shared
//

import UIKit

/// 월 캘린더 위젯 날짜 셀의 **높이 예산**.
///
/// 칸 수는 **주 수가 정한다** — 5주면 3개, 6주면 2개(제품 요구). 대신 칩 높이를 실제 행
/// 높이에서 역산해 그 개수가 언제나 들어가게 맞춘다.
///
/// 반대 방향(높이로 칸 수를 역산)도 해봤지만, 기기마다 위젯 높이가 몇 pt씩 달라 같은 5주
/// 달이 어떤 기기에선 3칸, 어떤 기기에선 2칸이 됐다. 개수를 고정하고 높이를 양보하는 쪽이
/// 사용자가 기대하는 그림에 맞다.
///
/// `ScheduleMetrics`와 같은 원칙: 줄높이를 **xSmall 콘텐츠 크기로 고정**해서 읽는다.
/// 뷰도 `.dynamicTypeSize(.xSmall)`로 렌더를 고정하므로 추정=렌더가 유지된다.
enum MonthWidgetMetrics {

    /// 셀 안 칩 최대 개수 — 이보다 많으면 글자가 너무 작은 게 아니라 셀이 지나치게 촘촘해진다.
    static let maximumSlots = 4

    /// 칩이 아무리 눌려도 이보다 얇아지지는 않는다 — 그 아래로는 글자가 형태를 잃는다.
    /// 대신 이 높이를 지키느라 칩이 셀을 넘칠 수 있어, 뷰가 셀을 잘라낸다.
    static let minimumChipHeight: CGFloat = 9

    /// 그 달의 주 행 수에 따른 셀당 칩 칸 수 — 4주 4개, 5주 3개, 6주 2개.
    static func slotCount(weekCount: Int) -> Int {
        switch weekCount {
        case ..<5: return maximumSlots
        case 5: return 3
        default: return 2
        }
    }

    /// 행 높이에 `slots`개가 정확히 들어가도록 역산한 칩 높이.
    static func chipHeight(rowHeight: CGFloat, slots: Int) -> CGFloat {
        chipHeight(
            rowHeight: rowHeight,
            slots: slots,
            headerHeight: dayNumberHeight + dayNumberGap,
            spacing: chipSpacing,
            minimum: minimumChipHeight,
            maximum: chipLine.rounded(.up)
        )
    }

    /// 순수 계산 버전 — 폰트 메트릭에 기대지 않아 결정론적으로 테스트할 수 있다.
    ///
    /// 상한을 두는 이유: 칩이 필요 이상으로 두꺼워지면(4주 달처럼 행이 넉넉할 때) 글자만
    /// 작은 채 배경만 커져 어색하다. 글자 줄높이에서 멈춘다.
    static func chipHeight(
        rowHeight: CGFloat,
        slots: Int,
        headerHeight: CGFloat,
        spacing: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat
    ) -> CGFloat {
        guard slots > 0 else { return minimum }
        let available = rowHeight - headerHeight - spacing * CGFloat(slots - 1)
        return min(maximum, max(minimum, available / CGFloat(slots)))
    }

    /// 칩 사이 세로 간격.
    static let chipSpacing: CGFloat = 1

    /// 날짜 숫자 줄 ↔ 첫 칩 사이 간격.
    ///
    /// 2pt로는 오늘 밑줄 바가 바로 아래 칩에 닿아 붙어 보인다 — 밑줄은 줄 상자 **맨 아래**에
    /// 얹히므로 이 간격이 곧 밑줄과 칩 사이의 전부다.
    static let dayNumberGap: CGFloat = Spacing.xs

    private static let compactTraits = UITraitCollection(preferredContentSizeCategory: .extraSmall)

    /// 칩 제목 한 줄 높이(xSmall 고정) — 뷰의 `.font(.caption)`과 **같은 스타일**이어야 한다.
    /// 어긋나면 예산과 렌더가 벌어져 칩이 셀을 넘치거나 빈 공간이 남는다.
    ///
    /// ⚠️ xSmall에서는 `caption`과 `caption2`가 둘 다 11pt로 클램프된다 — 지금은 날짜 줄과
    /// 같은 값이지만, 스타일이 다르므로 표준 크기에서는 갈린다. 그래서 분리해 둔다.
    static var chipLine: CGFloat {
        UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: compactTraits).lineHeight
    }

    /// 날짜 숫자 한 줄 높이 — 뷰가 날짜를 `.caption2`로 그리므로 칩과 다른 스타일을 잰다.
    static var dayNumberLine: CGFloat {
        UIFont.preferredFont(forTextStyle: .caption2, compatibleWith: compactTraits).lineHeight
    }

    /// 날짜 숫자 줄 높이. 오늘 밑줄 바를 위한 여유는 두지 않는다 — 뷰가 밑줄을 줄 상자
    /// **맨 아래에** 오프셋 없이 얹으면, 숫자엔 디센더가 없어 생기는 아래 여백에 정확히 들어간다.
    ///
    /// 뷰는 날짜를 칩보다 한 단계 작은 caption2로 그리므로 이 값은 실제보다 **넉넉하다**.
    /// 예산이 후한 방향이라 잘림은 생기지 않고, 남는 몫은 밑줄 여유로 쓰인다.
    static var dayNumberHeight: CGFloat { dayNumberLine.rounded(.up) }

}
