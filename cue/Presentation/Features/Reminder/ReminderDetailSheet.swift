//
//  ReminderDetailSheet.swift
//  cue / Presentation
//

import SwiftUI

/// 미리 알림 세부사항 입력 시트 — iOS "미리 알림" 세부사항 화면을 따른다.
///
/// 제목·메모는 상위 입력 행과 바인딩을 공유하고, 마감일(날짜·시간)은 시트 안에서
/// 고른다. 완료를 누르면 `onComplete(마감일, 시간포함여부)`로 값을 넘기고 닫힌다.
///
/// 날짜·시간 인라인 피커는 **한 번에 하나만** 펼친다 (iOS 미리 알림과 동일).
/// 토글이 켜진 행을 다시 탭하면 펼침/접힘이 바뀐다.
struct ReminderDetailSheet: View {
    @Binding var title: String
    @Binding var memo: String
    let onComplete: (_ dueDate: Date?, _ includesTime: Bool) -> Void

    @State private var hasDate = false
    @State private var hasTime = false
    @State private var dueDate = Date()
    @State private var expanded: PickerKind?
    @State private var pressedKind: PickerKind?
    @Environment(\.dismiss) private var dismiss

    /// 어떤 인라인 피커가 펼쳐졌는지 — 둘 다 켜져도 동시에 펼치진 않는다.
    private enum PickerKind { case date, time }

    /// 라벨 영역의 press 상태를 외부 `@State`로 흘려보낸다 — 셀 전체 하이라이트에 쓰인다.
    /// (배경은 여기서 칠하지 않고 행의 `listRowBackground`가 칠한다.)
    private struct RowPressReporter: ButtonStyle {
        let kind: PickerKind
        @Binding var pressed: PickerKind?

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .onChange(of: configuration.isPressed) { _, isPressed in
                    pressed = isPressed ? kind : nil
                }
        }
    }

    /// DatePicker·서브타이틀의 오전/오후·요일을 일관되게 한국어로 표시하기 위해 고정한다.
    private let koLocale = Locale(identifier: "ko_KR")

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("제목", text: $title)
                        .font(AppFont.titleLarge)
                        .foregroundStyle(.primary)
                    TextField("메모", text: $memo)
                        .font(AppFont.bodyLarge)
                        .foregroundStyle(.primary)
                }

                Section("날짜 및 시간") {
                    toggleRow(
                        kind: .date,
                        label: "날짜",
                        systemImage: "calendar",
                        isOn: hasDate,
                        subtitle: hasDate ? dateSubtitle : nil,
                        binding: dateBinding
                    )
                    if expanded == .date {
                        DatePicker("", selection: $dueDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .listRowInsets(EdgeInsets(
                                top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md
                            ))
                    }

                    toggleRow(
                        kind: .time,
                        label: "시간",
                        systemImage: "clock",
                        isOn: hasTime,
                        subtitle: hasTime ? timeSubtitle : nil,
                        binding: timeBinding
                    )
                    if expanded == .time {
                        HStack {
                            Spacer()
                            DatePicker("", selection: $dueDate, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                            Spacer()
                        }
                        .listRowInsets(EdgeInsets())
                    }
                }
            }
            .navigationTitle("세부사항")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        complete()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .environment(\.locale, koLocale)
        }
    }

    /// 날짜·시간 공통 토글 행 — 아이콘 + 라벨(+서브타이틀) + 트레일링 토글.
    /// 토글이 켜진 상태에서 라벨 영역을 탭하면 해당 피커의 펼침이 토글된다.
    /// (Form 행 안에서 `Button`은 제스처가 Toggle과 충돌하므로 `.onTapGesture`를 쓴다.)
    private func toggleRow(
        kind: PickerKind,
        label: String,
        systemImage: String,
        isOn: Bool,
        subtitle: String?,
        binding: Binding<Bool>
    ) -> some View {
        HStack {
            Button {
                if isOn { toggleExpanded(kind) }
            } label: {
                HStack(spacing: Spacing.md) {
                    Image(systemName: systemImage)
                        .foregroundStyle(
                            expanded == kind ? Color.accentColor : Color.secondary
                        )
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(label)
                            .foregroundStyle(.primary)
                        if let subtitle {
                            Text(subtitle)
                                .font(AppFont.bodySmall)
                                .foregroundStyle(.tint)
                        }
                    }
                }
                // 라벨 + 토글 사이 빈 공간까지 탭으로 인식시키려고 너비를 가능한 만큼 확장.
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(RowPressReporter(kind: kind, pressed: $pressedKind))

            Toggle("", isOn: binding)
                .labelsHidden()
        }
        // 셀 전체에 호버 느낌 — `listRowBackground`는 행 바닥 전체(좌우 끝까지) 채운다.
        // 단, 안 눌렸을 때는 `nil`을 넘겨야 시스템 그룹 박스 배경이 유지된다 (Color.clear는 박스를 덮어버림).
        .listRowBackground(pressHighlight(for: kind))
    }

    /// 누른 행만 강조 색을 돌려주고, 그 외엔 `nil`로 기본 행 배경을 유지한다.
    private func pressHighlight(for kind: PickerKind) -> Color? {
        pressedKind == kind ? Color.primary.opacity(0.08) : nil
    }

    /// 날짜 토글 — 켜면 날짜 피커를 펼치고, 끄면 시간도 같이 꺼진다 (시간은 날짜 없이 못 산다).
    private var dateBinding: Binding<Bool> {
        Binding(
            get: { hasDate },
            set: { isOn in
                withAnimation {
                    hasDate = isOn
                    if isOn {
                        expanded = .date
                    } else {
                        hasTime = false
                        expanded = nil
                    }
                }
            }
        )
    }

    /// 시간 토글 — 켜면 날짜도 자동으로 켜지고 시간 피커가 펼쳐진다.
    /// 끄면 그냥 접힌다 — 날짜 피커를 자동으로 다시 펼치진 않는다.
    private var timeBinding: Binding<Bool> {
        Binding(
            get: { hasTime },
            set: { isOn in
                withAnimation {
                    hasTime = isOn
                    if isOn {
                        hasDate = true
                        expanded = .time
                    } else {
                        expanded = nil
                    }
                }
            }
        )
    }

    /// 같은 행을 다시 탭하면 펼침을 닫고, 다른 행이면 그쪽으로 옮긴다.
    private func toggleExpanded(_ kind: PickerKind) {
        withAnimation {
            expanded = (expanded == kind) ? nil : kind
        }
    }

    /// "오늘" / "내일" / "5월 24일" — 마감일 행 서브타이틀.
    private var dateSubtitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(dueDate) { return "오늘" }
        if calendar.isDateInTomorrow(dueDate) { return "내일" }
        return dueDate.formatted(.dateTime.month().day().locale(koLocale))
    }

    /// "오전 11:00" / "오후 9:30" — 시간 행 서브타이틀.
    private var timeSubtitle: String {
        dueDate.formatted(.dateTime.hour().minute().locale(koLocale))
    }

    private func complete() {
        onComplete(hasDate ? dueDate : nil, hasTime)
        dismiss()
    }
}

#Preview {
    ReminderDetailSheet(title: .constant("장보기"), memo: .constant("")) { _, _ in }
}
