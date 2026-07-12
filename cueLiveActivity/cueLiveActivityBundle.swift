//
//  cueLiveActivityBundle.swift
//  cueLiveActivity
//
//  Created by Kim SungHun on 6/3/26.
//

import WidgetKit
import SwiftUI

@main
struct cueLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        // cue 실제 LA만 등록 — Xcode 템플릿 위젯(cueLiveActivity·Control·placeholder LA)은 제거했다.
        // 집중 LA는 AlarmKit이 구동(FocusAlarmLiveActivityWidget).
        ReminderLiveActivityWidget()
        ScheduleLiveActivityWidget()
        FocusAlarmLiveActivityWidget()
        MemoLiveActivityWidget()
    }
}
