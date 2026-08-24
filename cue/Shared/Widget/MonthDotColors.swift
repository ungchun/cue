//
//  MonthDotColors.swift
//  cue / Shared
//

import Foundation

/// 월 격자 한 칸에 찍을 점의 색 목록 — 홈 위젯(`CompactMonthGrid`)과
/// LA 월간 캘린더(`MonthCalendarView`)의 **단일 출처**.
///
/// 두 화면이 같은 달을 그리므로 규칙이 갈리면 안 된다. 예전엔 LA만 따로 계산해 일정만
/// 셌고, 그래서 할일뿐인 날이 LA에서만 빈 날로 보였다.
///
/// **항목 한 건당 점 하나**다 — 같은 색이 이어져도 접지 않는다. 점 사이가 벌어져 있어
/// 개수가 그대로 읽히므로, "몇 건 있는지"가 전할 수 있는 정보다.
enum MonthDotColors {

    /// 한 칸에 찍는 점의 최대 개수 — 가장 좁은 셀이 20pt 남짓이라 넷부터는 서로 붙는다.
    static let maximum = 3

    /// 그날 항목들의 색 — 등장 순서 그대로, 한 건당 하나. `nil`은 색이 없는 항목이며
    /// 그리는 쪽이 각자의 폴백 색(위젯=accent, LA=본문 색)으로 칠한다.
    static func colors(
        for items: [WidgetCalendarItem],
        limit: Int = maximum
    ) -> [String?] {
        items.prefix(limit).map(\.colorHex)
    }
}
