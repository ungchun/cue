//
//  FocusSessionEditorSheet.swift
//  cue / Presentation
//

import SwiftUI

/// 세션 1건을 새로 만들거나 기존 항목을 수정하는 중간(`.medium`) 디테일 시트.
/// `FocusSessionsListSheet` 위에 스택으로 떠 — 부모 목록 시트는 닫히지 않고 그 위에
/// 절반 높이로 올라온다.
struct FocusSessionEditorSheet: View {
    /// 모드 — `.create`면 빈 폼, `.edit(session)`이면 그 세션의 값으로 prefill.
    enum Mode: Equatable {
        case create
        case edit(FocusSession)
    }

    let mode: Mode
    @Bindable var viewModel: FocusViewModel

    @Environment(\.dismiss) private var dismiss

    /// 폼 입력값 — 시트가 떠 있는 동안 임시로 들고 있다가 저장 시 ViewModel에 반영.
    @State private var title: String = ""
    @State private var settings: FocusSettings = .default

    /// 어느 입력 필드가 포커스인지 추적. numberPad엔 Return이 없어 keyboard toolbar의
    /// "완료" 버튼이 `nil`로 떨어뜨려 키보드를 닫는다.
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title, focus, rest
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    TextField("세션 이름", text: $title)
                        .focused($focusedField, equals: .title)
                }
                Section("시간") {
                    minuteRow(label: "집중 시간", minutes: focusMinutesBinding, field: .focus)
                    if settings.isRepeating {
                        minuteRow(label: "휴식 시간", minutes: restMinutesBinding, field: .rest)
                    }
                }
                Section("반복") {
                    Toggle("반복", isOn: $settings.isRepeating)
                    if settings.isRepeating {
                        Stepper(value: $settings.cycleCount, in: 2...10) {
                            LabeledContent("사이클 수", value: "\(settings.cycleCount)회")
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "세션 수정" : "새 세션")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "저장" : "추가") {
                        save()
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
                // numberPad는 Return이 없어 키보드 위 toolbar의 "완료"로 닫는다.
                // 한글 키보드에도 떠 있지만 무해.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") { focusedField = nil }
                }
            }
        }
        .onAppear {
            // 시트가 처음 뜰 때 한 번 — 편집 모드면 그 세션의 값으로, 생성 모드면 빈 상태로
            // 폼을 초기화한다. 같은 인스턴스가 재사용될 일은 없지만 안전하게 매번 reset.
            if case .edit(let session) = mode {
                title = session.title
                settings = session.settings
            } else {
                title = ""
                settings = .default
                focusedField = .title
            }
        }
    }

    // MARK: - 파생값

    /// `.edit`이면 true.
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    /// 좌우 공백 제거된 제목 — 저장 가능 여부 판단·실제 저장에 사용.
    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 도메인의 초 단위 `focusDuration`을 분 단위 `Int`로 노출하는 binding.
    /// setter는 1~59분으로 클램프 — 60 이상을 막아 사용자 요청 범위를 보장한다.
    private var focusMinutesBinding: Binding<Int> {
        Binding(
            get: { Int(settings.focusDuration / 60) },
            set: { settings.focusDuration = TimeInterval(Self.clampMinutes($0) * 60) }
        )
    }

    /// 휴식도 같은 1~59분 범위.
    private var restMinutesBinding: Binding<Int> {
        Binding(
            get: { Int(settings.restDuration / 60) },
            set: { settings.restDuration = TimeInterval(Self.clampMinutes($0) * 60) }
        )
    }

    /// 입력값을 허용 범위로 클램프. 빈 입력(0)이나 음수는 1로, 60 이상은 59로.
    private static func clampMinutes(_ value: Int) -> Int {
        max(1, min(59, value))
    }

    // MARK: - 행 builder

    /// "집중 시간 [____] 분 [- +]" 한 줄. TextField로 직접 입력하거나 Stepper -/+로 ±1.
    /// 두 컨트롤이 같은 binding을 공유해 양쪽 어디로 바꿔도 즉시 동기화된다.
    private func minuteRow(label: String, minutes: Binding<Int>, field: Field) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", value: minutes, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: field)
                // "59"(2자리)가 넉넉히 들어가는 폭. xl(32)로는 좁고 xxl(48)이 자연스러움.
                .frame(width: Spacing.xxl)
            Text("분")
                .foregroundStyle(.secondary)
            Stepper("", value: minutes, in: 1...59)
                .labelsHidden()
        }
    }

    // MARK: - 저장

    /// 모드에 따라 추가 또는 수정 호출.
    private func save() {
        let name = trimmedTitle
        guard !name.isEmpty else { return }
        switch mode {
        case .create:
            viewModel.addSession(title: name, settings: settings)
        case .edit(let session):
            viewModel.updateSession(id: session.id, title: name, settings: settings)
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        FocusSessionEditorSheet(
            mode: .create,
            viewModel: FocusViewModel(dependencies: .preview)
        )
        .presentationDetents([.medium, .large])
    }
}
