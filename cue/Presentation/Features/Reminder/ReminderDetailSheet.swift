//
//  ReminderDetailSheet.swift
//  cue / Presentation
//

import SwiftUI

/// 미리 알림 세부사항 입력 시트 — iOS "미리 알림" 세부사항 화면을 따른다.
///
/// 생성·수정 양쪽에서 재사용한다. 초기값은 `init` 파라미터로 받고, 시트 내부에서
/// `@State`로 편집한다. 완료 시 `Draft`로 값을 넘겨주고 닫힌다 — 호출자가 add/update
/// 중 어느 쪽을 부를지 결정한다. X(취소)는 변경을 전부 버린다.
///
/// 날짜·시간 인라인 피커는 **한 번에 하나만** 펼친다 (iOS 미리 알림과 동일).
/// 토글이 켜진 행을 다시 탭하면 펼침/접힘이 바뀐다.
struct ReminderDetailSheet: View {
    /// 완료 시 호출자에게 전달되는 편집 결과.
    struct Draft {
        var title: String
        var memo: String
        var dueDate: Date?
        var includesTime: Bool
    }

    @State private var title: String
    @State private var memo: String
    @State private var hasDate: Bool
    @State private var hasTime: Bool
    @State private var dueDate: Date
    @State private var expanded: PickerKind?
    @State private var pressedKind: PickerKind?
    @State private var showingDiscardConfirmation = false
    @Environment(\.dismiss) private var dismiss

    private let onComplete: (Draft) -> Void

    // 변경사항 감지용 초기값 스냅샷 — X 누를 때 hasChanges 비교.
    private let initialTitle: String
    private let initialMemo: String
    private let initialDueDate: Date?
    private let initialIncludesTime: Bool

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
    private let koLocale = Locale.autoupdatingCurrent

    /// 생성·수정 양쪽을 한 init으로 다룬다 — 수정은 기존 값을 넣고, 생성은 기본값을 쓴다.
    init(
        title: String = "",
        memo: String = "",
        dueDate: Date? = nil,
        includesTime: Bool = false,
        onComplete: @escaping (Draft) -> Void
    ) {
        _title = State(initialValue: title)
        _memo = State(initialValue: memo)
        _hasDate = State(initialValue: dueDate != nil)
        _hasTime = State(initialValue: dueDate != nil && includesTime)
        _dueDate = State(initialValue: dueDate ?? Date())
        // 처음 들어왔을 때 펼침은 닫아둔다 — iOS 미리알림과 동일하게 사용자가 탭해서 펼친다.
        _expanded = State(initialValue: nil)
        self.initialTitle = title
        self.initialMemo = memo
        self.initialDueDate = dueDate
        self.initialIncludesTime = includesTime
        self.onComplete = onComplete
    }

    /// 사용자가 시트에 들어와서 한 글자라도 바꿨는지 — X 누를 때 확인 다이얼로그 띄울지 판단.
    private var hasChanges: Bool {
        if title != initialTitle { return true }
        if memo != initialMemo { return true }
        let currentDate: Date? = hasDate ? dueDate : nil
        if currentDate != initialDueDate { return true }
        if hasTime != initialIncludesTime { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // 시트 안엔 leading 아이콘이 없어 axis: .vertical TextField 정렬 이슈가 없음.
                    // Enter는 줄바꿈으로 두고, commit은 툴바 ✓ 버튼으로 명시.
                    TextField("Title", text: $title, axis: .vertical)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                    TextField("Note", text: $memo, axis: .vertical)
                        .font(.body)
                        .foregroundStyle(.primary)
                }

                Section("Date & Time") {
                    toggleRow(
                        kind: .date,
                        label: "Date",
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
                        label: "Time",
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
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // 회색 Liquid Glass capsule + X 심볼 — iOS 26 toolbar 기본 chrome.
                    // `Label` + `.labelStyle(.iconOnly)`로 VoiceOver title("닫기")까지 보장.
                    Button {
                        if hasChanges {
                            showingDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        Label("Close", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                    // X 버튼을 anchor 삼는 popover. iPhone(compact width)에선 기본이 sheet라
                    // presentationCompactAdaptation(.popover)로 popover 강제.
                    .popover(isPresented: $showingDiscardConfirmation) {
                        discardPopover
                            .presentationCompactAdaptation(.popover)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // prominent capsule은 전역 tint(.primary)를 상속해 라이트=검정/다크=흰색 —
                    // 라벨은 배경 반전색(systemBackground)으로 명시해 항상 대비를 보장한다
                    // (흰색 고정은 다크에서 흰 캡슐에 묻힘 — 페이월 CTA와 같은 관용구).
                    Button {
                        complete()
                    } label: {
                        Label("Save", systemImage: "checkmark")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(Color(.systemBackground))
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .keyboardDismissToolbar()
            .environment(\.locale, koLocale)
        }
    }

    /// X 버튼 popover 컨텐츠 — 제목(leading, 명시적 줄바꿈) + destructive 버튼. 외부 탭으로 dismiss(=취소).
    /// iOS 시스템 알림 크기 — 제목 `.headline`, 버튼 iOS 26 `.glass` capsule + 빨간 텍스트 명시.
    private var discardPopover: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Discard Changes?")
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Button(role: .destructive) {
                showingDiscardConfirmation = false
                dismiss()
            } label: {
                // 회색 system fill capsule + 빨간 destructive 텍스트 — iOS native alert와 동일.
                // `.glass` style은 fill이 너무 투명해 직접 background로 명시.
                Text("Discard Changes")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.lg)
        // iPhone popover는 content ideal size를 작게 잡아 minWidth로 명시적 강제 — 화면 ~60% 정도.
        .frame(minWidth: 240)
    }

    /// 날짜·시간 공통 토글 행 — 아이콘 + 라벨(+서브타이틀) + 트레일링 토글.
    /// 토글이 켜진 상태에서 라벨 영역을 탭하면 해당 피커의 펼침이 토글된다.
    private func toggleRow(
        kind: PickerKind,
        label: LocalizedStringKey,
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
                            // 서브타이틀은 iOS 미리알림과 동일하게 캡션 크기 — 라벨보다 확연히 작게.
                            Text(subtitle)
                                .font(.caption)
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
                // 앱 전역 무채색 tint가 다크 모드에서 ON 트랙을 흰색으로 만든다 — 시스템 표준(초록)으로.
                .tint(.green)
        }
        // 셀 전체에 호버 느낌 — `listRowBackground`는 행 바닥 전체(좌우 끝까지) 채운다.
        // 단, 안 눌렸을 때는 `nil`을 넘겨야 시스템 그룹 박스 배경이 유지된다.
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
        if calendar.isDateInToday(dueDate) { return String(localized: "Today") }
        if calendar.isDateInTomorrow(dueDate) { return String(localized: "Tomorrow") }
        return dueDate.formatted(.dateTime.month().day().locale(koLocale))
    }

    /// "오전 11:00" / "오후 9:30" — 시간 행 서브타이틀.
    private var timeSubtitle: String {
        dueDate.formatted(.dateTime.hour().minute().locale(koLocale))
    }

    private func complete() {
        onComplete(Draft(
            title: title,
            memo: memo,
            dueDate: hasDate ? dueDate : nil,
            includesTime: hasTime
        ))
        dismiss()
    }
}

#Preview {
    ReminderDetailSheet(title: "장보기", memo: "") { _ in }
}
