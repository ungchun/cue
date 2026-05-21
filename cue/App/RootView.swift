//
//  RootView.swift
//  cue / App
//

import SwiftUI

/// 앱의 첫 화면. 하단 탭바를 소유하고, 미리알림 탭에서는 탭바 위에
/// 리스트 칩 액세서리(`ReminderListBar`)를 띄운다.
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
        .tabViewBottomAccessory {
            if selectedTab == .reminder {
                ReminderListBar(viewModel: reminderViewModel)
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
