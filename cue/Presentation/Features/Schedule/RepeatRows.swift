//
//  RepeatRows.swift
//  cue / Presentation
//

import SwiftUI

/// 반복 행 묶음 — 반복 메뉴 피커(안 함…사용자화) + 사용자화 요약 행(상세 화면 진입) +
/// 반복 종료(안 함/날짜 + 날짜 피커). 이벤트 편집 시트와 할일 세부사항 시트가 공용한다.
///
/// 호출자는 이 행들을 자신의 Section 안에 배치한다. `anchorDate`는 반복 종료 날짜의
/// 하한이자 기본값 기준(이벤트 시작일·할일 마감일).
struct RepeatRows: View {
    @Binding var recurrence: EventEditDraft.Recurrence
    @Binding var recurrenceEnd: EventEditDraft.RecurrenceEnd
    let anchorDate: Date

    var body: some View {
        repeatMenuRow
        if isCustomRecurrence {
            repeatSummaryRow
        }
        if showsEndRepeat {
            endRepeatRow
            if case .onDate(let date) = recurrenceEnd {
                DatePicker(
                    "On Date",
                    selection: Binding(
                        get: { date },
                        set: { recurrenceEnd = .onDate($0) }
                    ),
                    in: anchorDate...,
                    displayedComponents: .date
                )
            }
        }
    }

    /// 반복 메뉴 — 프리셋 + 사용자화. 사용자화의 tag는 현재 custom 값 그대로 써서
    /// 상세를 어떻게 편집해도 메뉴 선택이 유지된다.
    private var repeatMenuRow: some View {
        Picker("Repeat", selection: $recurrence) {
            ForEach(menuOptions, id: \.self) { option in
                Text(label(for: option)).tag(option)
            }
        }
    }

    private var menuOptions: [EventEditDraft.Recurrence] {
        var options = EventEditDraft.Recurrence.presets
        switch recurrence {
        case .custom, .foreign:
            options.append(recurrence)
        default:
            // 메뉴에서 사용자화를 고르면 이 기본값(매일 1회)에서 시작 — Apple과 동일.
            options.append(.custom(.init(frequency: .daily, interval: 1)))
        }
        return options
    }

    private var isCustomRecurrence: Bool {
        switch recurrence {
        case .custom, .foreign: true
        default: false
        }
    }

    /// "반복: 매년 7월, 8월 및 12월 ›" — 사용자화 요약 + 상세 화면 진입.
    private var repeatSummaryRow: some View {
        NavigationLink {
            RepeatOptionScreen(recurrence: $recurrence)
        } label: {
            // Apple 캘린더 요약 행과 동일 — 본문보다 작고 옅게.
            Text("Repeat: \(summary)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var summary: String {
        if case .custom(let rule) = recurrence { return rule.summaryText }
        return String(localized: "Custom")
    }

    /// 반복 종료 — 반복이 실제로 설정됐을 때만. foreign은 원본 보존이라 노출하지 않는다.
    private var showsEndRepeat: Bool {
        switch recurrence {
        case .none, .foreign: false
        default: true
        }
    }

    private var endRepeatRow: some View {
        Picker("End Repeat", selection: $recurrenceEnd) {
            Text("Never").tag(EventEditDraft.RecurrenceEnd.never)
            Text("On Date").tag(onDateTag)
        }
    }

    /// "날짜" 항목의 tag — 이미 날짜면 현재 값(선택 유지), 아니면 기본값(기준일+1개월).
    private var onDateTag: EventEditDraft.RecurrenceEnd {
        if case .onDate = recurrenceEnd { return recurrenceEnd }
        let base = Calendar.current.date(byAdding: .month, value: 1, to: anchorDate) ?? anchorDate
        return .onDate(base)
    }

    private func label(for option: EventEditDraft.Recurrence) -> String {
        switch option {
        case .none: String(localized: "Never")
        case .daily: String(localized: "Every Day")
        case .weekly: String(localized: "Every Week")
        case .biweekly: String(localized: "Every 2 Weeks")
        case .monthly: String(localized: "Every Month")
        case .yearly: String(localized: "Every Year")
        case .custom, .foreign: String(localized: "Custom")
        }
    }
}
