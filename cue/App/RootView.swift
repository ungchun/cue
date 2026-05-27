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
    /// `focus`/`schedule`은 탭만 먼저 들이고 화면은 다음 사이클에서 — 시스템 표준
    /// `ContentUnavailableView`로 placeholder를 둬 빈 화면이 어색하지 않게 한다.
    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .focus:
            ContentUnavailableView(
                "집중",
                systemImage: "timer",
                description: Text("뽀모도로·앱 차단은 다음 사이클에서.")
            )
        case .reminder: ReminderView(viewModel: reminderViewModel)
        case .schedule:
            ContentUnavailableView(
                "일정",
                systemImage: "calendar",
                description: Text("시간순 일정 뷰는 다음 사이클에서.")
            )
        case .settings: SettingsView()
        }
    }
}

#Preview {
    RootView(dependencies: .preview)
}
