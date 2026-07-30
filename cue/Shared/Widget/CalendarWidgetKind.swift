//
//  CalendarWidgetKind.swift
//  cue / Shared
//

import Foundation

/// 홈 화면 캘린더 위젯의 `kind` 문자열 단일 출처.
///
/// `reloadAllTimelines()`는 Live Activity까지 전부 재생성해 위젯 갱신 예산을 태운다.
/// 예산이 마르면 시스템이 자정·정시 타임라인을 미루기 시작해 **오히려 더 낡은 그림**이
/// 남으므로, 갱신이 필요한 캘린더 위젯만 골라 집는다.
///
/// 이동형 3종은 `WidgetRangeKind.widgetKind`가 알지만 고정형(이번달)은 셰브런이 없어
/// 오프셋도 없고 따라서 `WidgetRangeKind` case도 없다 — 그 하나 때문에 이 타입이 있다.
///
/// > 위젯을 추가하면 `all`에도 넣는다. 빠뜨리면 그 위젯만 조용히 낡은다.
enum CalendarWidgetKind {

    /// 항상 이번 달만 보여주는 고정형 — 이동하지 않으므로 `WidgetRangeKind`에 대응이 없다.
    static let fixedMonth = "azhy.cue.widget.monthFixed"

    /// 캘린더 위젯 전체. 이동형은 `WidgetRangeKind`에서 가져와 두 곳이 갈라지지 않게 한다.
    static let all: [String] = [fixedMonth] + WidgetRangeKind.allCases.map(\.widgetKind)
}
