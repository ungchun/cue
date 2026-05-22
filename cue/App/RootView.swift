//
//  RootView.swift
//  cue / App
//

import SwiftUI

/// 앱의 첫 화면. 하단 탭바를 소유하고 탭에 맞는 화면을 보여준다.
struct RootView: View {
    @State private var selectedTab: AppTab = .reminder
    @State private var reminderViewModel: ReminderViewModel

    init(dependencies: Dependencies) {
        _reminderViewModel = State(initialValue: ReminderViewModel(dependencies: dependencies))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    NavigationStack {
                        screen(for: tab)
                    }
                }
            }
        }
    }

    /// 탭에 대응하는 화면을 만든다.
    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .reminder: ReminderView(viewModel: reminderViewModel)
        case .settings: SettingsView()
        }
    }
}

#Preview {
    RootView(dependencies: .preview)
}
