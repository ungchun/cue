//
//  RootView.swift
//  cue / App
//

import SwiftUI

/// 앱의 첫 화면. 시스템(Apple) 탭바에 5탭(메모·일정·할일·집중·설정)을 한 캡슐로 두고,
/// 우하단에 메시지 버튼을 플로팅(FAB)으로 띄운다. 탭바·칩바·스크롤 축소 등 네이티브 동작 유지.
struct RootView: View {
    @State private var selectedTab: AppTab = .reminder
    @State private var reminderViewModel: ReminderViewModel
    @State private var scheduleViewModel: ScheduleViewModel
    @State private var focusViewModel: FocusViewModel
    @State private var memoViewModel: MemoViewModel
    /// 전역 설정의 단일 소유자 — 설정 탭이 편집하고, 여기서 화면 모드를 앱 전체에 적용한다.
    @State private var settingsViewModel: SettingsViewModel

    init(dependencies: Dependencies) {
        _reminderViewModel = State(initialValue: ReminderViewModel(dependencies: dependencies))
        _scheduleViewModel = State(initialValue: ScheduleViewModel(dependencies: dependencies))
        _focusViewModel = State(initialValue: FocusViewModel(dependencies: dependencies))
        _memoViewModel = State(initialValue: MemoViewModel(dependencies: dependencies))
        _settingsViewModel = State(initialValue: SettingsViewModel(dependencies: dependencies))
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
        // minimize 동작은 할일 탭에서만 — 다른 탭에선 `.never`로 항상 expanded.
        .tabBarMinimizeBehavior(selectedTab == .reminder ? .onScrollDown : .never)
        // 할일 탭일 때만 리스트 선택 chip bar를 탭바에 부착.
        .tabViewBottomAccessory(isEnabled: selectedTab == .reminder) {
            ListSelectorChipBar(
                lists: reminderViewModel.lists,
                selection: reminderViewModel.selection,
                onSelectList: { reminderViewModel.select($0) },
                onSelectFilter: { reminderViewModel.selectFilter($0) }
            )
        }
        // 화면 모드(라이트/다크/시스템)를 앱 전체에 적용. `.system`이면 nil → 시스템 따름.
        .preferredColorScheme(settingsViewModel.settings.colorScheme.colorScheme)
        // 앱 시작 시 저장된 설정을 불러온다 — 화면 모드 반영 + 시작 탭으로 한 번 이동.
        .task {
            await settingsViewModel.onAppear()
            if let startTab = AppTab(rawValue: settingsViewModel.settings.startTabID) {
                selectedTab = startTab
            }
        }
    }

    /// 탭에 대응하는 화면을 만든다.
    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .memo: MemoView(viewModel: memoViewModel)
        case .focus: FocusView(viewModel: focusViewModel)
        case .reminder: ReminderView(viewModel: reminderViewModel)
        case .schedule: ScheduleView(viewModel: scheduleViewModel)
        case .settings: SettingsView(viewModel: settingsViewModel)
        }
    }
}

#Preview {
    RootView(dependencies: .preview)
}
