//
//  ReminderReadView.swift
//  cue / Presentation
//

import SwiftUI

/// 할일 세부사항 시트의 보기 모드 본문 — 컨테이너(ReminderDetailSheet)의 `Form` 안에 놓이는 읽기 전용 섹션.
///
/// 이벤트 보기(EventReadView)와 같은 구성: 제목 블록 / 일시·반복 / 목록·우선순위 / 위치 알림.
/// 값이 없는 행은 숨긴다. 일시는 기기 로케일·시간대로 보여준다.
struct ReminderReadView: View {
    /// 시트를 연 시점 값(보기 모드에선 저장 전이라 바뀌지 않는다).
    let reminder: Reminder
    let lists: [ReminderList]
    /// 완료 상태 — 컨테이너가 낙관적으로 뒤집어 넘긴다.
    let isCompleted: Bool
    /// nil이면 완료 원을 그리지 않는다.
    let onToggleCompletion: (() -> Void)?

    var body: some View {
        Section {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.smd) {
                if let onToggleCompletion {
                    completionButton(action: onToggleCompletion)
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(reminder.title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(isCompleted ? Color.secondary : Color.primary)
                    if let notes = reminder.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .textSelection(.enabled)
            }
            if let dueDate = reminder.dueDate {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(dueDate.formatted(date: .complete, time: .omitted))
                        .foregroundStyle(.primary)
                    if reminder.includesTime {
                        Text(dueDate.formatted(date: .omitted, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
                if recurrence != .none {
                    LabeledContent("Repeat", value: repeatText)
                    if let endDate = reminder.recurrence?.endDate {
                        LabeledContent("End Repeat", value: endDate.formatted(date: .abbreviated, time: .omitted))
                    }
                }
            }
        }

        if list != nil || reminder.priority != ReminderPriority.none {
            Section {
                if let list {
                    LabeledContent("List") {
                        HStack(spacing: Spacing.sm) {
                            Circle()
                                .fill(list.colorHex.flatMap(Color.init(hex:)) ?? .secondary)
                                .frame(width: Spacing.sm, height: Spacing.sm)
                            Text(list.title)
                        }
                    }
                }
                if reminder.priority != ReminderPriority.none {
                    LabeledContent("Priority", value: reminder.priority.label)
                }
            }
        }

        if let alarm = reminder.locationAlarm {
            Section {
                LabeledContent {
                    Text(alarm.proximity.label)
                } label: {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(alarm.title)
                            .foregroundStyle(.primary)
                        if let address = alarm.address {
                            Text(address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 완료

    /// 할일 탭 행과 같은 원 — 완료면 목록 색으로 채운다.
    private func completionButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: isCompleted ? "largecircle.fill.circle" : "circle")
                .font(.title2.weight(.thin))
                .foregroundStyle(isCompleted ? listColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Completed")
        .accessibilityAddTraits(isCompleted ? .isSelected : [])
    }

    // MARK: - 파생값

    private var list: ReminderList? {
        lists.first { $0.id == reminder.listID }
    }

    private var listColor: Color {
        list?.colorHex.flatMap(Color.init(hex:)) ?? .accentColor
    }

    private var recurrence: EventEditDraft.Recurrence {
        EventEditDraft.Recurrence(reminderRule: reminder.recurrence)
    }

    private var repeatText: String {
        if case .custom(let rule) = recurrence { return rule.summaryText }
        return recurrence.label
    }
}
