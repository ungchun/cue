//
//  DayProgressRing.swift
//  cueLiveActivity
//
//  compact Dynamic Island 우측 — 잔여 시간을 나타내는 회색 링.
//  기준은 LA 게시 후 ~8시간 수명 고정(게시 시각 기준점은 App Group `ringAnchor`).
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

    /// 진행 링이 카운트다운할 구간 — LA 게시 시각부터 8시간(시스템 LA 수명).
    /// 기준점이 아직 없으면(비정상) 지금부터 8시간으로 폴백한다.
    static func range(now: Date = .now) -> ClosedRange<Date> {
        let anchorStamp = SharedAppGroup.defaults.double(forKey: SharedAppGroup.Keys.ringAnchor)
        let anchor = anchorStamp > 0 ? Date(timeIntervalSince1970: anchorStamp) : now
        return anchor...anchor.addingTimeInterval(8 * 60 * 60)
    }
}
