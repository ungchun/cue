//
//  LiveAlwaysOnItemsView.swift
//  cue / Presentation
//
//  설정 > 라이브 > 항목 상세 페이지 — 항상 표시 대상(메모/할일/일정) 토글과
//  할일 범위(오늘/예정/전체/사용자 리스트)를 한 화면에서 설정한다.
//  중첩 메뉴의 펼침 점프를 피하려고 iOS 설정 표준(행 → 상세 페이지) 패턴을 쓴다.
//

import SwiftUI

struct LiveAlwaysOnItemsView: View {
    let viewModel: SettingsViewModel

    var body: some View {
        List {
            Section {
                Toggle("메모", isOn: memoBinding)
                Toggle("할일", isOn: reminderBinding)
                // 할일 범위 — 할일이 켜져 있을 때만 등장(점진 노출).
                if viewModel.settings.liveAlwaysOnReminder {
                    Picker("할일 범위", selection: scopeBinding) {
                        Text("오늘").tag("today")
                        Text("예정").tag("scheduled")
                        Text("전체").tag("all")
                        ForEach(viewModel.reminderLists, id: \.id) { list in
                            Text(list.title).tag(list.id)
                        }
                    }
                }
                Toggle("일정", isOn: scheduleBinding)
            } footer: {
                Text("선택한 항목의 라이브가 자동으로 표시됩니다. 항목을 모두 끄면 항상 표시가 꺼집니다.")
                    .font(.caption2)
            }
            .tint(.green)
        }
        .navigationTitle("항목")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var memoBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.liveAlwaysOnMemo },
            set: { newValue in Task { await viewModel.setLiveAlwaysOnMemo(newValue) } }
        )
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.liveAlwaysOnReminder },
            set: { newValue in Task { await viewModel.setLiveAlwaysOnReminder(newValue) } }
        )
    }

    private var scheduleBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.liveAlwaysOnSchedule },
            set: { newValue in Task { await viewModel.setLiveAlwaysOnSchedule(newValue) } }
        )
    }

    private var scopeBinding: Binding<String> {
        Binding(
            get: { viewModel.settings.liveAlwaysOnReminderScopeID },
            set: { newValue in Task { await viewModel.setLiveAlwaysOnReminderScopeID(newValue) } }
        )
    }
}

#Preview {
    NavigationStack {
        LiveAlwaysOnItemsView(viewModel: SettingsViewModel(dependencies: .preview))
    }
}
