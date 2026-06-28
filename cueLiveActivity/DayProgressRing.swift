//
//  DayProgressRing.swift
//  cueLiveActivity
//
//  compact Dynamic Island 우측 — 잔여 시간을 나타내는 회색 링.
//  기준은 설정(`ProgressRingBasis`)에 따라 둘 중 하나다(메인 앱이 App Group에 미러):
//   • day24    — 오늘 자정까지(00시 꽉 참 → 자정 카운트다운). 기본·현재 동작.
//   • activity8h — LA 게시 후 ~8시간 수명(게시 시각 기준점은 App Group `ringAnchor`).
//  `ProgressView(timerInterval:)`이 시스템 위임으로 자동 갱신하므로 앱이 매분 update할 필요가 없다.
//

import SwiftUI
import WidgetKit

struct DayProgressRing: View {
    var body: some View {
        ProgressView(
            timerInterval: Self.range(),
            countsDown: true,
            label: { EmptyView() },
            currentValueLabel: { EmptyView() }
        )
        .progressViewStyle(.circular)
        .tint(.gray)
        // 방향은 iOS 기본(시계방향, 왼→오) — 미러 없음.
    }

    /// 진행 링이 카운트다운할 구간. 설정 기준(App Group 미러)에 따라 자정까지 또는 8시간 수명.
    /// 위젯 타깃은 Domain의 `ProgressRingBasis`를 모르므로 rawValue 문자열로 비교한다
    /// (메인 앱이 `ProgressRingBasis.rawValue`를 그대로 미러한 값 — "day24"/"activity8h").
    static func range(now: Date = .now) -> ClosedRange<Date> {
        let group = SharedAppGroup.defaults
        let basis = group.string(forKey: SharedAppGroup.Keys.ringBasis) ?? "day24"

        if basis == "activity8h" {
            let anchorStamp = group.double(forKey: SharedAppGroup.Keys.ringAnchor)
            let anchor = anchorStamp > 0 ? Date(timeIntervalSince1970: anchorStamp) : now
            return anchor...anchor.addingTimeInterval(8 * 60 * 60)
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return start...end
    }
}
