//
//  RepeatOptionScreen.swift
//  cue / Presentation
//

import SwiftUI

/// 반복 옵션 화면 — 빈도(안 함/매일/매주/2주마다/매월/매년)를 고르면 그 빈도의
/// 상세 옵션이 바로 아래 펼쳐진다: 간격 + 매주는 요일, 매월은 날짜/조건(서수 요일),
/// 매년은 월 + 요일 조건. 마지막에 반복 종료(안 함/날짜).
///
/// 별도의 "사용자 설정" 단계를 두지 않는다 — 상세를 건드리는 순간 내부적으로
/// `Recurrence.custom`이 되고, 프리셋과 동치로 되돌아오면 프리셋으로 정규화된다.
/// 우리 편집기로 표현 못 하는 규칙(`.foreign`)이면 보존 안내만 보여준다.
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
                frequencySection
                if let rule = editingRule {
                    detailSections(rule)
                }
                if recurrence != EventEditDraft.Recurrence.none {
                    endSection
                }
            }
        }
        .navigationTitle("Repeat")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 빈도

    private var frequencySection: some View {
        Section {
            ForEach(EventEditDraft.Recurrence.presets, id: \.self) { preset in
                checkRow(presetLabel(preset), checked: bucket == preset) {
                    // 빈도를 새로 고르면 상세 지정은 초기화 — 새 출발점.
                    recurrence = preset
                }
            }
        }
    }

    /// 현재 값이 속한 빈도 행 — custom도 빈도·간격 기준으로 해당 행에 체크를 유지한다
    /// (매주 + 요일 지정을 골라도 "매주"에 체크가 남게).
    private var bucket: EventEditDraft.Recurrence {
        switch recurrence {
        case .none, .daily, .weekly, .biweekly, .monthly, .yearly, .foreign:
            return recurrence
        case .custom(let rule):
            switch rule.frequency {
            case .daily: return .daily
            case .weekly: return rule.interval == 2 ? .biweekly : .weekly
            case .monthly: return .monthly
            case .yearly: return .yearly
            }
        }
    }

    // MARK: - 빈도별 상세

    /// 편집용 규칙 — 프리셋도 동치의 CustomRule로 펼쳐 상세 UI가 항상 그려지게 한다.
    private var editingRule: EventEditDraft.CustomRule? {
        switch recurrence {
        case .none, .foreign: nil
        case .daily: .init(frequency: .daily, interval: 1)
        case .weekly: .init(frequency: .weekly, interval: 1)
        case .biweekly: .init(frequency: .weekly, interval: 2)
        case .monthly: .init(frequency: .monthly, interval: 1)
        case .yearly: .init(frequency: .yearly, interval: 1)
        case .custom(let rule): rule
        }
    }

    /// 상세 변경 반영 — 프리셋과 동치면 프리셋으로 정규화(EK 규칙도 그대로 단순 유지).
    private func update(_ rule: EventEditDraft.CustomRule) {
        let isPlain = rule.weekdays.isEmpty && rule.monthDays.isEmpty
            && rule.months.isEmpty && rule.ordinal == nil
        if isPlain {
            switch (rule.frequency, rule.interval) {
            case (.daily, 1): recurrence = .daily; return
            case (.weekly, 1): recurrence = .weekly; return
            case (.weekly, 2): recurrence = .biweekly; return
            case (.monthly, 1): recurrence = .monthly; return
            case (.yearly, 1): recurrence = .yearly; return
            default: break
            }
        }
        recurrence = .custom(rule)
    }

    @ViewBuilder
    private func detailSections(_ rule: EventEditDraft.CustomRule) -> some View {
        Section {
            Stepper(value: intervalBinding, in: 1...99) {
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
            // "조건 지정…"(서수 요일)이 켜지면 일자 그리드는 숨긴다 — Apple과 동일한 배타 모드.
            ordinalSection(rule)
            if rule.ordinal == nil {
                Section {
                    numberGrid(range: 1...31, columns: 7, selected: rule.monthDays) { day in
                        toggleMembership(\.monthDays, day)
                    }
                } footer: {
                    Text("If none are selected, the start date's day is used.")
                }
            }
        case .yearly:
            Section {
                numberGrid(range: 1...12, columns: 4, selected: rule.months, label: { monthLabel($0) }) { month in
                    toggleMembership(\.months, month)
                }
            } footer: {
                Text("If none are selected, the start date's month is used.")
            }
            ordinalSection(rule)
        }
    }

    /// 서수 요일("N째 X요일") — Apple 캘린더의 "조건 지정…" 스위치 + 서수·요일 휠.
    @ViewBuilder
    private func ordinalSection(_ rule: EventEditDraft.CustomRule) -> some View {
        Section {
            Toggle("On the...", isOn: ordinalEnabledBinding)
            if rule.ordinal != nil {
                HStack(spacing: Spacing.zero) {
                    Picker("", selection: ordinalBinding) {
                        ForEach(Self.ordinals, id: \.self) { value in
                            Text(ordinalLabel(value)).tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    Picker("", selection: ordinalWeekdayBinding) {
                        ForEach(1...7, id: \.self) { weekday in
                            Text(calendar.weekdaySymbols[weekday - 1]).tag(weekday)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
                // 휠 두 개를 나란히 — 시스템 휠 기본 높이 근사(토큰 밖 치수, 디자인 의도값).
                .frame(height: 160)
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

    /// 현재 편집 규칙 바인딩 — 쓰기는 항상 `update`를 거쳐 프리셋 정규화를 태운다.
    private var customBinding: Binding<EventEditDraft.CustomRule> {
        Binding(
            get: { editingRule ?? .init(frequency: .weekly, interval: 1) },
            set: { update($0) }
        )
    }

    private var intervalBinding: Binding<Int> {
        Binding(
            get: { customBinding.wrappedValue.interval },
            set: { value in
                var rule = customBinding.wrappedValue
                rule.interval = value
                customBinding.wrappedValue = rule
            }
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

    /// Apple과 동일한 서수 목록 — 첫째…다섯째 + 마지막(-1).
    private static let ordinals = [1, 2, 3, 4, 5, -1]

    private func ordinalLabel(_ value: Int) -> String {
        switch value {
        case 1: String(localized: "First")
        case 2: String(localized: "Second")
        case 3: String(localized: "Third")
        case 4: String(localized: "Fourth")
        case 5: String(localized: "Fifth")
        default: String(localized: "Last")
        }
    }

    /// 스위치 켜면 기본값(첫째 + 로케일 주 시작 요일), 끄면 서수 지정 해제.
    private var ordinalEnabledBinding: Binding<Bool> {
        Binding(
            get: { customBinding.wrappedValue.ordinal != nil },
            set: { isOn in
                var rule = customBinding.wrappedValue
                rule.ordinal = isOn ? 1 : nil
                rule.ordinalWeekday = isOn ? calendar.firstWeekday : nil
                customBinding.wrappedValue = rule
            }
        )
    }

    private var ordinalBinding: Binding<Int> {
        Binding(
            get: { customBinding.wrappedValue.ordinal ?? 1 },
            set: { value in
                var rule = customBinding.wrappedValue
                rule.ordinal = value
                customBinding.wrappedValue = rule
            }
        )
    }

    private var ordinalWeekdayBinding: Binding<Int> {
        Binding(
            get: { customBinding.wrappedValue.ordinalWeekday ?? calendar.firstWeekday },
            set: { value in
                var rule = customBinding.wrappedValue
                rule.ordinalWeekday = value
                customBinding.wrappedValue = rule
            }
        )
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
