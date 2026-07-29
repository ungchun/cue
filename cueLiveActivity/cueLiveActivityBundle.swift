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
        // 홈 화면 캘린더 위젯 — LA와 같은 익스텐션에 묶어 EventKit 조회 코드를 공유한다.
        //
        // 등록 순서가 곧 **갤러리에 보이는 순서**다. 무료로 쓸 수 있는 "이번달"을 맨 앞에 두고,
        // 뒤로 갈수록 좁은 구간(월 → 3일 → 1일)으로 간다 — 처음 여는 사람이 무엇부터 봐야
        // 할지 헷갈리지 않는다.
        FixedMonthCalendarWidget()
        MonthCalendarWidget()
        ThreeDayCalendarWidget()
        OneDayCalendarWidget()
    }
}
