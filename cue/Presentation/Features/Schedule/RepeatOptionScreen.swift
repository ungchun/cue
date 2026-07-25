//
//  RepeatOptionScreen.swift
//  cue / Presentation
//

import SwiftUI

/// 반복 "사용자화" 상세 화면 — Apple 캘린더의 사용자화 화면을 따른다:
/// 빈도(매일/매주/매월/매년) + 간격 + 빈도별 지정(매주=요일, 매월=날짜/조건, 매년=월/조건).
///
/// 프리셋·반복 종료는 메인 시트(EventDetailSheet)의 반복 섹션이 담당한다.
/// 우리 편집기로 표현 못 하는 규칙(`.foreign`)이면 보존 안내만 보여준다.
struct RepeatOptionScreen: View {
    @Binding var recurrence: EventEditDraft.Recurrence

    private let calendar = Calendar.current

    var body: some View {
        List {
            if case .custom(let rule) = recurrence {
                customSection(rule)
            } else {
                Section {
                    Text("This repeat rule can't be edited here and will be kept as is.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Custom")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 사용자화 편집

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
                Text(rule.intervalText)
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
                            Text(EventEditDraft.CustomRule.ordinalLabel(value)).tag(value)
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

    /// Apple과 동일한 서수 목록 — 첫째…다섯째 + 마지막(-1).
    private static let ordinals = [1, 2, 3, 4, 5, -1]

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
                return .init(frequency: .daily, interval: 1)
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
}

// MARK: - 요약·라벨 텍스트

extension EventEditDraft.CustomRule {
    /// 서수 라벨 — 사용자화 휠과 요약("첫째 월요일")이 공유한다.
    static func ordinalLabel(_ value: Int) -> String {
        switch value {
        case 1: String(localized: "First")
        case 2: String(localized: "Second")
        case 3: String(localized: "Third")
        case 4: String(localized: "Fourth")
        case 5: String(localized: "Fifth")
        default: String(localized: "Last")
        }
    }

    /// 간격 문구 — "2주마다" 류. 간격 1이면 "매주" 류 프리셋 문구.
    var intervalText: String {
        if interval == 1 {
            return switch frequency {
            case .daily: String(localized: "Every Day")
            case .weekly: String(localized: "Every Week")
            case .monthly: String(localized: "Every Month")
            case .yearly: String(localized: "Every Year")
            }
        }
        return switch frequency {
        case .daily: String(localized: "Every \(interval) days")
        case .weekly: String(localized: "Every \(interval) weeks")
        case .monthly: String(localized: "Every \(interval) months")
        case .yearly: String(localized: "Every \(interval) years")
        }
    }

    /// 메인 시트 요약 — "매년 7월, 8월 및 12월" / "매월 첫째 월요일" / "매주 월요일 및 수요일".
    var summaryText: String {
        let calendar = Calendar.current
        var parts = [intervalText]
        switch frequency {
        case .daily:
            break
        case .weekly:
            if !weekdays.isEmpty {
                parts.append(Self.joinedList(weekdays.sorted().map { calendar.weekdaySymbols[$0 - 1] }))
            }
        case .monthly:
            if let ordinal, let ordinalWeekday {
                parts.append("\(Self.ordinalLabel(ordinal)) \(calendar.weekdaySymbols[ordinalWeekday - 1])")
            } else if !monthDays.isEmpty {
                parts.append(Self.joinedList(monthDays.sorted().map(String.init)))
            }
        case .yearly:
            if !months.isEmpty {
                parts.append(Self.joinedList(months.sorted().map { calendar.monthSymbols[$0 - 1] }))
            }
            if let ordinal, let ordinalWeekday {
                parts.append("\(Self.ordinalLabel(ordinal)) \(calendar.weekdaySymbols[ordinalWeekday - 1])")
            }
        }
        return parts.joined(separator: " ")
    }

    /// 로케일 열거 조인 — ko "7월, 8월 및 12월", en "July, August, and December".
    private static func joinedList(_ items: [String]) -> String {
        ListFormatter.localizedString(byJoining: items)
    }
}
