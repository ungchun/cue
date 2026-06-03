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
        // minimize 동작도 할일 탭에서만 — 다른 탭(집중/일정/설정)에선 `.never`로
        // 항상 expanded. 그렇지 않으면 inline 상태에서 우측 [설정] 누른 직후 탭바가
        // minimize 그대로 유지되고 가운데가 빈 자리로 남는다(chip bar accessory도 hide).
        // 탭 전환 시 system이 자동 expanded 복귀시키지 않으므로 직접 분기.
        .tabBarMinimizeBehavior(selectedTab == .reminder ? .onScrollDown : .never)
        // `tabViewBottomAccessory(isEnabled:content:)` — Apple이 정확히 이 시나리오용으로
        // 제공한 시그니처. `isEnabled: false`면 system이 modifier·영역 모두 자동 hide,
        // `isEnabled: true`면 chip bar 표시. modifier 자체를 if/else로 분기시키지 말고
        // 이 파라미터를 쓰라는 게 Apple 공식 권장 — view identity 변동이 없어 탭 전환
        // ping-pong이 일어나지 않는다.
        .tabViewBottomAccessory(isEnabled: selectedTab == .reminder) {
            ListSelectorChipBar(
                lists: reminderViewModel.lists,
                selection: reminderViewModel.selection,
                onSelectList: { reminderViewModel.select($0) },
                onSelectFilter: { reminderViewModel.selectFilter($0) }
            )
        }
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

#Preview {
    RootView(dependencies: .preview)
}
