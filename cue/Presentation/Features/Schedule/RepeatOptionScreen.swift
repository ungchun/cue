//
//  RepeatOptionScreen.swift
//  cue / Presentation
//

import SwiftUI

/// 반복 옵션 화면 — Apple 캘린더의 "반복" 화면을 따른다: 프리셋 목록 + 사용자 설정
/// (빈도·간격·요일/일자/월 지정) + 반복 종료(안 함/날짜).
///
/// `EventDetailSheet`에서 NavigationLink로 진입한다. 우리 편집기로 표현 못 하는
/// 규칙(`.foreign`)이면 목록 대신 보존 안내만 보여준다 — 잘못 덮어쓰는 것보다 낫다.
struct RepeatOptionScreen: View {
    @Binding var recurrence: EventEditDraft.Recurrence
    @Binding var recurrenceEnd: EventEditDraft.RecurrenceEnd
    /// 반복 종료 날짜의 기본값 기준 — 이벤트 시작일.
    let eventStart: Date

    private let calendar = Calendar.current

    var body: some View {
        List {
            if recurrence == .foreign {
                Section {
                    Text("This repeat rule can't be edited here and will be kept as is.")
                        .foregroundStyle(.secondary)
                }
            } else {
                presetSection
                if case .custom(let rule) = recurrence {
                    customSection(rule)
                }
                if recurrence != EventEditDraft.Recurrence.none {
                    endSection
                }
            }
        }
        .navigationTitle("Repeat")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 프리셋

    private var presetSection: some View {
        Section {
            ForEach(EventEditDraft.Recurrence.presets, id: \.self) { preset in
                checkRow(presetLabel(preset), checked: recurrence == preset) {
                    recurrence = preset
                }
            }
            checkRow(String(localized: "Custom"), checked: recurrence.isCustom) {
                if !recurrence.isCustom {
                    // 사용자 설정 진입 기본값 — 매주 1회(Apple과 동일한 출발점).
                    recurrence = .custom(.init(frequency: .weekly, interval: 1))
                }
            }
        }
    }

    // MARK: - 사용자 설정

    @ViewBuilder
    private func customSection(_ rule: EventEditDraft.CustomRule) -> some View {
        Section {
            Picker("Frequency", selection: customBinding.frequency) {
                Text("Every Day").tag(EventEditDraft.CustomRule.Frequency.daily)
                Text("Every Week").tag(EventEditDraft.CustomRule.Frequency.weekly)
                Text("Every Month").tag(EventEditDraft.CustomRule.Frequency.monthly)
                Text("Every Year").tag(EventEditDraft.CustomRule.Frequency.yearly)
            }
            Stepper(value: customBinding.interval, in: 1...99) {
                Text(intervalLabel(rule))
            }
        }

        switch rule.frequency {
        case .daily:
            EmptyView()
        case .weekly:
            Section {
                // EKWeekday rawValue는 1=일요일 고정. 표시 순서는 로케일 주 시작을 따른다.
                ForEach(orderedWeekdays, id: \.self) { weekday in
                    checkRow(calendar.weekdaySymbols[weekday - 1], checked: rule.weekdays.contains(weekday)) {
                        toggleMembership(\.weekdays, weekday)
                    }
                }
            } footer: {
                Text("If none are selected, the start date's weekday is used.")
            }
        case .monthly:
            Section {
                numberGrid(range: 1...31, columns: 7, selected: rule.monthDays) { day in
                    toggleMembership(\.monthDays, day)
                }
            } footer: {
                Text("If none are selected, the start date's day is used.")
            }
        case .yearly:
            Section {
                numberGrid(range: 1...12, columns: 4, selected: rule.months, label: { monthLabel($0) }) { month in
                    toggleMembership(\.months, month)
                }
            } footer: {
                Text("If none are selected, the start date's month is used.")
            }
        }
    }

    // MARK: - 반복 종료

    private var endSection: some View {
        Section("End Repeat") {
            checkRow(String(localized: "Never"), checked: recurrenceEnd == .never) {
                recurrenceEnd = .never
            }
            checkRow(String(localized: "On Date"), checked: isOnDate) {
                if !isOnDate { recurrenceEnd = .onDate(defaultEndDate) }
            }
            if case .onDate(let date) = recurrenceEnd {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { date },
                        set: { recurrenceEnd = .onDate($0) }
                    ),
                    in: eventStart...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
            }
        }
    }

    private var isOnDate: Bool {
        if case .onDate = recurrenceEnd { return true }
        return false
    }

    /// 종료 날짜 기본값 — 시작일 + 1개월(바로 지난 날짜가 나오지 않게).
    private var defaultEndDate: Date {
        calendar.date(byAdding: .month, value: 1, to: eventStart) ?? eventStart
    }

    // MARK: - 구성 요소

    private func checkRow(_ title: String, checked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if checked {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 숫자(일자·월) 다중 선택 그리드 — 선택된 칸은 primary 원형 배경으로 반전.
    private func numberGrid(
        range: ClosedRange<Int>, columns: Int, selected: Set<Int>,
        label: @escaping (Int) -> String = { "\($0)" }, toggle: @escaping (Int) -> Void
    ) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns), spacing: Spacing.sm) {
            ForEach(Array(range), id: \.self) { value in
                Button {
                    toggle(value)
                } label: {
                    Text(label(value))
                        .font(.callout)
                        .foregroundStyle(selected.contains(value) ? Color(.systemBackground) : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            Capsule().fill(selected.contains(value) ? Color.primary : Color(.tertiarySystemFill))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - 바인딩·헬퍼

    /// custom 케이스 페이로드 바인딩 — custom이 아닐 때 접근하면 기본값(방어).
    private var customBinding: Binding<EventEditDraft.CustomRule> {
        Binding(
            get: {
                if case .custom(let rule) = recurrence { return rule }
                return .init(frequency: .weekly, interval: 1)
            },
            set: { recurrence = .custom($0) }
        )
    }

    private func toggleMembership(_ keyPath: WritableKeyPath<EventEditDraft.CustomRule, Set<Int>>, _ value: Int) {
        var rule = customBinding.wrappedValue
        if rule[keyPath: keyPath].contains(value) {
            rule[keyPath: keyPath].remove(value)
        } else {
            rule[keyPath: keyPath].insert(value)
        }
        customBinding.wrappedValue = rule
    }

    /// 로케일 주 시작 요일부터 도는 1…7(EKWeekday raw) 순서.
    private var orderedWeekdays: [Int] {
        let first = calendar.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    private func monthLabel(_ month: Int) -> String {
        calendar.shortMonthSymbols[month - 1]
    }

    private func presetLabel(_ preset: EventEditDraft.Recurrence) -> String {
        switch preset {
        case .none: String(localized: "Never")
        case .daily: String(localized: "Every Day")
        case .weekly: String(localized: "Every Week")
        case .biweekly: String(localized: "Every 2 Weeks")
        case .monthly: String(localized: "Every Month")
        case .yearly: String(localized: "Every Year")
        case .custom, .foreign: String(localized: "Custom")
        }
    }

    private func intervalLabel(_ rule: EventEditDraft.CustomRule) -> String {
        switch rule.frequency {
        case .daily: String(localized: "Every \(rule.interval) days")
        case .weekly: String(localized: "Every \(rule.interval) weeks")
        case .monthly: String(localized: "Every \(rule.interval) months")
        case .yearly: String(localized: "Every \(rule.interval) years")
        }
    }
}
