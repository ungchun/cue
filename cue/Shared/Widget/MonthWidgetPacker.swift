//
//  MonthWidgetPacker.swift
//  cue / Shared
//

import Foundation

/// 월 캘린더 위젯이 쓰는 항목 정렬 규칙.
///
/// 칸 배치 자체는 `MonthWeekPacker`가 **주 단위**로 한다(연속 일정을 같은 줄에 놓으려면
/// 하루만 봐서는 안 된다). 여기 남은 건 데이터 소스가 날짜별 목록을 만들 때 쓰는 정렬뿐이다.
enum MonthWidgetPacker {

    /// 셀 안 표시 순서 — 종일 → 시간 일정 → 미리알림, 같은 종류면 시작 시각, 그다음 제목.
    ///
    /// 제목까지 비교하는 건 미적 취향이 아니라 **결정론** 때문이다. 같은 시각 항목의 순서가
    /// 타임라인 갱신마다 뒤집히면 위젯이 이유 없이 깜빡인다.
    static func sorted(_ items: [WidgetCalendarItem]) -> [WidgetCalendarItem] {
        items.sorted { lhs, rhs in
            if lhs.kind != rhs.kind { return lhs.kind < rhs.kind }
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            if lhs.title != rhs.title { return lhs.title < rhs.title }
            return lhs.id < rhs.id
        }
    }
}
