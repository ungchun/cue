//
//  LiveOrderEditView.swift
//  cue / Presentation
//

import SwiftUI

/// 항상 표시 라이브의 잠금화면 순서를 바꾸는 전용 화면 — 설정 > 라이브 > 표시 순서에서
/// push된다. 세 행(메모/일정/할일)을 드래그해 재배치하면 즉시 저장된다.
///
/// 편집 모드를 상시로 켠다(`editMode = .active`) — 행이 세 개뿐인 화면이라 "편집" 버튼을
/// 한 번 더 누르게 할 이유가 없고, 들어오자마자 드래그 핸들이 보여야 화면의 용도가 읽힌다.
struct LiveOrderEditView: View {
    let viewModel: SettingsViewModel

    /// 드래그 중 재배치를 즉시 반영하는 로컬 사본 — 저장(async)을 기다렸다 그리면
    /// 드래그를 놓는 순간 행이 원위치로 튕겼다가 돌아온다.
    @State private var order: [LiveActivityKind]

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        _order = State(initialValue: viewModel.settings.resolvedLiveOrder)
    }

    var body: some View {
        List {
            Section {
                ForEach(order, id: \.self) { kind in
                    Text(title(for: kind))
                }
                .onMove { from, to in
                    order.move(fromOffsets: from, toOffset: to)
                    Task { await viewModel.setLiveAlwaysOnOrder(order) }
                }
            } footer: {
                // 이 화면의 유일한 규칙 — 리스트 순서가 곧 잠금화면 순서.
                Text("The first item appears at the top of your Lock Screen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .environment(\.editMode, .constant(.active))
        .contentMargins(.top, Spacing.sm, for: .scrollContent)
        .navigationTitle("Display Order")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 라이브 섹션의 행 이름과 같은 키를 쓴다 — 같은 대상이 화면마다 다른 이름이면 안 된다.
    private func title(for kind: LiveActivityKind) -> LocalizedStringKey {
        switch kind {
        case .memo: "Memo"
        case .schedule: "Schedule"
        case .reminder: "Tasks"
        case .focus: ""   // 항상 표시 대상 아님 — resolvedLiveOrder가 이미 걸러 온다.
        }
    }
}
