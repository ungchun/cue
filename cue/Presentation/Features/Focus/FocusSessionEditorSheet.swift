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
    /// 새 세션 모드일 때 TextField에 자동 포커스를 잡는다.
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    TextField("세션 이름", text: $title)
                        .focused($titleFocused)
                }
                Section("시간") {
                    Stepper(
                        value: $settings.focusDuration,
                        in: 60...(180 * 60),
                        step: 60
                    ) {
                        LabeledContent("집중 시간", value: minuteLabel(settings.focusDuration))
                    }
                    if settings.isRepeating {
                        Stepper(
                            value: $settings.restDuration,
                            in: 60...(60 * 60),
                            step: 60
                        ) {
                            LabeledContent("휴식 시간", value: minuteLabel(settings.restDuration))
                        }
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
                titleFocused = true
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

    /// 초 → "N분" 라벨.
    private func minuteLabel(_ seconds: TimeInterval) -> String {
        "\(Int(seconds / 60))분"
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
