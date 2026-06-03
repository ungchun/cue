//
//  RootView.swift
//  cue / App
//

import SwiftUI

/// 앱의 첫 화면. 하단 탭바를 소유하고 탭에 맞는 화면을 보여준다.
///
/// iOS 26 패턴 적용 — Apple Music 미니 플레이어와 동일 동작:
/// - `tabBarMinimizeBehavior(.onScrollDown)`: 컨텐츠를 아래로 스크롤하면 탭바가 자동
///   collapse. active 탭과 `.search` role 탭만 작은 원형으로 남는다.
/// - `tabViewBottomAccessory { ... }`: 할일 탭일 때만 리스트 선택 chip bar를 부착.
///   expanded(스크롤 위)에선 탭바 위에 별도 capsule, inline(스크롤 다운)에선 좌측
///   active 탭과 우측 `.search` 탭 사이로 slide.
struct RootView: View {
    @State private var selectedTab: AppTab = .reminder
    @State private var reminderViewModel: ReminderViewModel
    @State private var scheduleViewModel: ScheduleViewModel
    @State private var focusViewModel: FocusViewModel

    init(dependencies: Dependencies) {
        _reminderViewModel = State(initialValue: ReminderViewModel(dependencies: dependencies))
        _scheduleViewModel = State(initialValue: ScheduleViewModel(dependencies: dependencies))
        _focusViewModel = State(initialValue: FocusViewModel(dependencies: dependencies))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab, role: tab.role) {
                    NavigationStack {
                        screen(for: tab)
                    }
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        // `tabViewBottomAccessory` modifier는 content가 빈 view여도 accessory **영역
        // 자체는 system이 유지**한다 — 다른 탭에서 빈 회색 capsule이 보임. 그래서
        // modifier 자체를 할일 탭일 때만 부착해 영역 자체가 사라지게 한다.
        .modifier(ReminderChipBarAccessory(
            isActive: selectedTab == .reminder,
            viewModel: reminderViewModel
        ))
    }

    /// 탭에 대응하는 화면을 만든다.
    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .focus: FocusView(viewModel: focusViewModel)
        case .reminder: ReminderView(viewModel: reminderViewModel)
        case .schedule: ScheduleView(viewModel: scheduleViewModel)
        case .settings: SettingsView()
        }
    }
}

/// `tabViewBottomAccessory`를 조건부로 부착한다. 활성 시에만 chip bar accessory를
/// 붙이고, 비활성 시엔 modifier 자체를 안 붙여 system accessory 영역 자체가 사라진다.
///
/// `tabViewBottomAccessory`의 content를 `EmptyView`로 비우는 방식은 영역이 유지되어
/// 다른 탭에서 빈 회색 자리가 보이는 부작용이 있다 — 그래서 modifier 자체를 분기.
private struct ReminderChipBarAccessory: ViewModifier {
    let isActive: Bool
    let viewModel: ReminderViewModel

    @ViewBuilder
    func body(content: Content) -> some View {
        if isActive {
            content.tabViewBottomAccessory {
                ListSelectorChipBar(
                    lists: viewModel.lists,
                    selection: viewModel.selection,
                    onSelectList: { viewModel.select($0) },
                    onSelectFilter: { viewModel.selectFilter($0) }
                )
            }
        } else {
            content
        }
    }
}

#Preview {
    RootView(dependencies: .preview)
}
