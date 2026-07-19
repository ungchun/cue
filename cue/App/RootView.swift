//
//  RootView.swift
//  cue / App
//

import SwiftUI

/// 앱의 첫 화면. 시스템(Apple) 탭바에 5탭(메모·일정·할일·집중·설정)을 한 캡슐로 두고,
/// 우하단에 메시지 버튼을 플로팅(FAB)으로 띄운다. 탭바·칩바·스크롤 축소 등 네이티브 동작 유지.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dependencies) private var dependencies
    @Environment(\.openURL) private var openURL
    /// 강제 업데이트 필요 — 원격 최소 버전 판정 결과. true면 App Store 이동 알림(회피 불가).
    @State private var isUpdateRequired = false
    /// App Store 앱 페이지 — ASC 앱 정보의 Apple ID.
    private let appStoreURL = URL(string: "https://apps.apple.com/app/id6789932436")!
    @State private var selectedTab: AppTab = .reminder
    @State private var reminderViewModel: ReminderViewModel
    @State private var scheduleViewModel: ScheduleViewModel
    @State private var focusViewModel: FocusViewModel
    @State private var memoViewModel: MemoViewModel
    /// 전역 설정의 단일 소유자 — 설정 탭이 편집하고, 여기서 화면 모드를 앱 전체에 적용한다.
    @State private var settingsViewModel: SettingsViewModel
    /// 앱 전반 토스트 코디네이터 — 여기서 소유해 환경으로 주입하고, 상단 오버레이를 부착한다.
    @State private var toastCenter = ToastCenter()

    init(dependencies: Dependencies) {
        _reminderViewModel = State(initialValue: ReminderViewModel(dependencies: dependencies))
        _scheduleViewModel = State(initialValue: ScheduleViewModel(dependencies: dependencies))
        _focusViewModel = State(initialValue: FocusViewModel(dependencies: dependencies, isPremiumUser: PremiumAccess.isPremium))
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
        // 앱 전체를 무채색(.primary, 라이트=검정/다크=하양)으로 — 탭 선택·메뉴 아이콘·토글·버튼의
        // accent(보라)·시스템 파랑 강조를 없앤다. 세션 색·메모 LA 색 등 명시적 색은 영향 없음.
        .tint(.primary)
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
        // 상단에서 내려오는 앱 공통 라이브 토스트 — 어느 탭에서 켜도 같은 오버레이가 뜬다.
        .liveToastOverlay(toastCenter)
        .environment(\.toastCenter, toastCenter)
        // 화면 모드(라이트/다크/시스템)를 앱 전체에 적용. `.system`이면 nil → 시스템 따름.
        .preferredColorScheme(settingsViewModel.settings.colorScheme.colorScheme)
        // 강제 업데이트 — 최소 요구 버전 미만이면 알림. 확인은 App Store 이동뿐이고,
        // 누른 뒤에도 플래그를 다시 켜 알림이 재표시된다(업데이트 전엔 앱 사용 불가).
        .alert("Update Required", isPresented: $isUpdateRequired) {
            Button("OK") {
                openURL(appStoreURL)
                // alert 닫힘이 바인딩을 false로 되돌린 **뒤에** 다시 켜야 재표시된다.
                Task { @MainActor in isUpdateRequired = true }
            }
        } message: {
            Text("Please update to the latest version.")
        }
        .task {
            let version = Bundle.main
                .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            isUpdateRequired = await dependencies.checkForcedUpdate(currentVersion: version)
        }
        // 앱 시작 시 저장된 설정을 불러온다 — 화면 모드 반영 + 시작 탭으로 한 번 이동 + 항상 표시 게시.
        .task {
            await settingsViewModel.onAppear()
            if let startTab = AppTab(rawValue: settingsViewModel.settings.startTabID) {
                selectedTab = startTab
            }
            await startAlwaysOnActivities(settingsViewModel.settings)
        }
        // 포그라운드 복귀 — 시스템이 8시간 후 LA를 종료했을 수 있어 다시 게시한다
        // (VM이 이 실행에서 켠 상태면 각자 건너뛴다 — 중복 게시 없음).
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await startAlwaysOnActivities(settingsViewModel.settings) }
        }
        // 설정에서 항상 표시(또는 항목)를 켜는 순간 즉시 게시 — 꺼짐 방향은 건드리지 않는다
        // (사용자가 수동으로 띄운 LA를 죽이지 않기 위해).
        .onChange(of: settingsViewModel.settings) { old, new in
            let newlyOn = { (kind: KeyPath<AppSettings, Bool>) -> Bool in
                new.liveAlwaysOn && new[keyPath: kind] && !(old.liveAlwaysOn && old[keyPath: kind])
            }
            let scopeChanged = new.liveAlwaysOn && new.liveAlwaysOnReminder
                && old.liveAlwaysOnReminderScopeID != new.liveAlwaysOnReminderScopeID
            Task {
                if newlyOn(\.liveAlwaysOnMemo) { await memoViewModel.startAlwaysOnLiveActivity() }
                if newlyOn(\.liveAlwaysOnReminder) { await reminderViewModel.startAlwaysOnLiveActivity() }
                else if scopeChanged { await reminderViewModel.startAlwaysOnLiveActivity(force: true) }
                if newlyOn(\.liveAlwaysOnSchedule) { await scheduleViewModel.startAlwaysOnLiveActivity() }
            }
        }
    }

    /// 항상 표시 설정에 따라 선택된 항목의 LA를 자동 게시한다 — 각 VM이 중복·권한·빈 데이터를 거른다.
    private func startAlwaysOnActivities(_ settings: AppSettings) async {
        guard settings.liveAlwaysOn else { return }
        if settings.liveAlwaysOnMemo { await memoViewModel.startAlwaysOnLiveActivity() }
        if settings.liveAlwaysOnReminder { await reminderViewModel.startAlwaysOnLiveActivity() }
        if settings.liveAlwaysOnSchedule { await scheduleViewModel.startAlwaysOnLiveActivity() }
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
