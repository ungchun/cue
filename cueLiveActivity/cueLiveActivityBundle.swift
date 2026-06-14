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
        cueLiveActivity()
        cueLiveActivityControl()
        // default `cueLiveActivityLiveActivity`는 placeholder라 cue 3종 LA로 대체.
        // 집중 LA는 AlarmKit이 구동(FocusAlarmLiveActivityWidget) — 옛 FocusLiveActivityWidget는 제거.
        ReminderLiveActivityWidget()
        ScheduleLiveActivityWidget()
        FocusAlarmLiveActivityWidget()
    }
}
