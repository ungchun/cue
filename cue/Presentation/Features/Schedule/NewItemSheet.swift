//
//  NewItemSheet.swift
//  cue / Presentation
//

import EventKit
import SwiftUI

/// 일정 탭 + 버튼이 띄우는 생성 시트 — 상단 토글로 일정(EventDetailSheet)과
/// 할일(ReminderDetailSheet)을 오가며 만든다.
///
/// 바꿀 때 넘기는 건 제목뿐이다 — 날짜·반복 등은 두 쪽 의미가 달라(종일/시간 범위 vs 마감일)
/// 옮기면 오히려 틀린 값이 된다. 할일은 오늘 날짜를 켠 채, 기본 목록으로 시작한다.
struct NewItemSheet: View {
    let eventStore: EKEventStore
    let reminderEditor: ScheduleReminderEditor
    let onEventCompletion: (EventEditOutcome) -> Void

    @State private var kind: NewItemKind = .event
    @State private var title = ""

    var body: some View {
        Group {
            switch kind {
            case .event:
                EventDetailSheet(
                    eventStore: eventStore,
                    title: title,
                    onSwitchKind: { switchKind(to: .reminder, carrying: $0) },
                    onCompletion: onEventCompletion
                )
            case .reminder:
                ReminderDetailSheet(
                    title: title,
                    dueDate: .now,
                    lists: reminderEditor.lists,
                    listID: reminderEditor.defaultListID,
                    onSwitchKind: { switchKind(to: .event, carrying: $0) }
                ) { draft in
                    Task {
                        await reminderEditor.create(
                            title: draft.title, notes: draft.memo,
                            dueDate: draft.dueDate, includesTime: draft.includesTime,
                            recurrence: draft.recurrence, listID: draft.listID
                        )
                    }
                }
            }
        }
        .task { await reminderEditor.refreshLists() }
    }

    private func switchKind(to newKind: NewItemKind, carrying title: String) {
        self.title = title
        kind = newKind
    }
}
