//
//  DayProgressRing.swift
//  cueLiveActivity
//
//  compact Dynamic Island 우측 — 하루 24시간 잔여를 나타내는 회색 링.
//  00시에 꽉 차고 시간이 갈수록 줄어든다(자정까지 카운트다운). `ProgressView(timerInterval:)`이
//  시스템 위임으로 자동 갱신하므로 앱이 매분 update할 필요가 없다(FocusAlarm 링과 동일 방식).
//

import SwiftUI
import WidgetKit

struct DayProgressRing: View {
    var body: some View {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return ProgressView(
            timerInterval: start...end,
            countsDown: true,
            label: { EmptyView() },
            currentValueLabel: { EmptyView() }
        )
        .progressViewStyle(.circular)
        .tint(.gray)
        // 방향은 iOS 기본(시계방향, 왼→오) — 미러 없음.
    }
}
