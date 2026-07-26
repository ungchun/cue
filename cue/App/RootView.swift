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
    /// 온보딩에 양보된 강제 업데이트 알림 — 커버 dismiss 후 재무장한다.
    @State private var pendingUpdateAlert = false
    /// App Store 앱 페이지 — ASC 앱 정보의 Apple ID.
    private let appStoreURL = URL(string: "https://apps.apple.com/app/id6789932436")!
    /// 설정 로드 전 첫 프레임의 탭 — 기본 시작 탭(메모)과 일치시켜 깜빡임 없이 시작한다.
    @State private var selectedTab: AppTab = .memo
    @State private var reminderViewModel: ReminderViewModel
    @State private var scheduleViewModel: ScheduleViewModel
    @State private var focusViewModel: FocusViewModel
    @State private var memoViewModel: MemoViewModel
    /// 전역 설정의 단일 소유자 — 설정 탭이 편집하고, 여기서 화면 모드를 앱 전체에 적용한다.
    @State private var settingsViewModel: SettingsViewModel
    /// 첫 실행 온보딩 — 설정 로드 후 완주 여부·기존 설치 여부로 표시 결정.
    @State private var onboardingViewModel: OnboardingViewModel
    @State private var showsOnboarding = false
    /// 기존 설치 흔적 — init에서 동기로 읽는다(프리페치 task가 스냅샷을 저장하기 **전**이어야
    /// 신규 설치가 기존 사용자로 오판되지 않는다).
    private let hadPriorInstall: Bool
    /// 앱 전반 토스트 코디네이터 — 여기서 소유해 환경으로 주입하고, 상단 오버레이를 부착한다.
    @State private var toastCenter = ToastCenter()
    /// 프리미엄 토스트 탭으로 여는 전역 페이월 — 게이트에 걸린 화면이 어디든 여기 시트 하나로 뜬다.
    @State private var showsGatePaywall = false
    /// reconcile 직렬 체인 — 확정 판정 전이가 연달아 와도 실행 순서 = 전이 순서를 보장한다.
    @State private var reconcileChain: Task<Void, Never>?

    /// 항상 표시 게시 전 엔타이틀먼트 확정용 — `start()`(cueApp)와 경쟁해도 게시 시점 값이 정확하게.
    private let premiumStore: PremiumStore

    init(dependencies: Dependencies, premiumStore: PremiumStore) {
        self.premiumStore = premiumStore
        _reminderViewModel = State(initialValue: ReminderViewModel(dependencies: dependencies, premiumStore: premiumStore))
        _scheduleViewModel = State(initialValue: ScheduleViewModel(dependencies: dependencies, premiumStore: premiumStore))
        _focusViewModel = State(initialValue: FocusViewModel(dependencies: dependencies, premiumStore: premiumStore))
        _memoViewModel = State(initialValue: MemoViewModel(dependencies: dependencies, premiumStore: premiumStore))
        _settingsViewModel = State(initialValue: SettingsViewModel(dependencies: dependencies))
        _onboardingViewModel = State(initialValue: OnboardingViewModel(dependencies: dependencies))
        hadPriorInstall = dependencies.detectPriorInstall()
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
        // 탭 진입 분석 — 시작 탭 포함 첫 표시 1회 + 이후 전환마다.
        .onChange(of: selectedTab, initial: true) { _, tab in
            dependencies.analytics.log(.tabViewed(tab: tab.rawValue))
        }
        // minimize 동작은 할일 탭에서만 — 다른 탭에선 `.never`로 항상 expanded.
        .tabBarMinimizeBehavior(selectedTab == .reminder ? .onScrollDown : .never)
        // 할일 탭일 때만 리스트 선택 chip bar를 탭바에 부착.
        .tabViewBottomAccessory(isEnabled: selectedTab == .reminder) {
            ListSelectorChipBar(
                lists: reminderViewModel.visibleLists,
                selection: reminderViewModel.selection,
                onSelectList: { reminderViewModel.select($0) },
                onSelectFilter: { reminderViewModel.selectFilter($0) }
            )
        }
        // 상단에서 내려오는 앱 공통 라이브 토스트 — 어느 탭에서 켜도 같은 오버레이가 뜬다.
        .liveToastOverlay(toastCenter)
        .environment(\.toastCenter, toastCenter)
        // 프리미엄 토스트 탭 → 페이월. 핸들러 주입은 선언적 시트와 달리 1회면 충분해 task에서.
        .task { toastCenter.premiumTapHandler = { showsGatePaywall = true } }
        .sheet(isPresented: $showsGatePaywall) {
            PremiumPaywallView(source: "gate")
        }
        // 화면 모드(라이트/다크/시스템)를 앱 전체에 적용. `.system`이면 nil → 시스템 따름.
        .preferredColorScheme(settingsViewModel.settings.colorScheme.colorScheme)
        // 강제 업데이트 — 최소 요구 버전 미만이면 알림. 확인은 App Store 이동뿐이고,
        // 누른 뒤에도 플래그를 다시 켜 알림이 재표시된다(업데이트 전엔 앱 사용 불가).
        .alert("Update Required", isPresented: $isUpdateRequired) {
            Button("OK") {
                dependencies.analytics.log(.forcedUpdateTapped)
                openURL(appStoreURL)
                // alert 닫힘이 바인딩을 false로 되돌린 **뒤에** 다시 켜야 재표시된다.
                Task { @MainActor in isUpdateRequired = true }
            }
        } message: {
            Text("Please update to the latest version.")
        }
        // 강제 업데이트 알럿 노출 기록 — OK 후 재표시 루프도 각각 한 번의 노출로 센다.
        // 온보딩 커버가 떠 있으면 **알림이 우선**: 같은 뷰의 동시 presentation은 하나가
        // 조용히 버려지므로, 커버를 내리고 dismiss 완료를 신호로 알림을 다시 켠다
        // (고정 지연은 dismiss가 늦으면 알림이 또 버려진 채 영영 안 뜰 수 있다).
        .onChange(of: isUpdateRequired) { _, shown in
            guard shown else { return }
            if showsOnboarding {
                showsOnboarding = false
                isUpdateRequired = false
                pendingUpdateAlert = true
                return
            }
            dependencies.analytics.log(.forcedUpdatePrompted)
        }
        // 온보딩 커버가 내려간 뒤 보류된 강제 업데이트 알림 재무장 — dismiss 전환이
        // 끝날 시간만 짧게 두고 켠다(같은 프레임 재-present는 버려질 수 있음).
        .onChange(of: showsOnboarding) { _, showing in
            guard !showing, pendingUpdateAlert else { return }
            pendingUpdateAlert = false
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                isUpdateRequired = true
            }
        }
        .task {
            let version = Bundle.main
                .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            isUpdateRequired = await dependencies.checkForcedUpdate(currentVersion: version)
        }
        // 앱 시작 프리페치 — 탭 진입을 기다리지 않고 할일·일정 첫 적재를 병렬로 미리 끝낸다.
        // 이미 권한이 허용된 경우에만 동작(프롬프트 없음)하고, 첫 탭의 onAppear와는
        // 각 ViewModel의 first-load single-flight로 합류해 fetch가 중복되지 않는다.
        .task {
            async let reminders: Void = reminderViewModel.prefetch()
            async let schedule: Void = scheduleViewModel.prefetch()
            _ = await (reminders, schedule)
        }
        // 앱 시작 시 저장된 설정을 불러온다 — 화면 모드 반영 + 시작 탭으로 한 번 이동 + 항상 표시 게시.
        .task {
            await settingsViewModel.onAppear()
            if let startTab = AppTab(rawValue: settingsViewModel.settings.startTabID) {
                selectedTab = startTab
            }
            // 첫 실행 온보딩 — 완주했으면 없음, 기존 사용자는 조용히 완주 처리(업데이트로
            // 온보딩이 처음 생겨도 잘 쓰던 사람에겐 안 띄운다), 신규 설치만 표시.
            switch OnboardingViewModel.launchDecision(
                settings: settingsViewModel.settings, hasPriorInstall: hadPriorInstall
            ) {
            case .show:
                // 강제 업데이트 알림이 우선 — 업데이트가 필요하면 온보딩을 띄우지 않는다.
                if !isUpdateRequired {
                    // 시작 마커 먼저 — 도중 종료돼도 다음 실행에 이어서 보여준다.
                    await onboardingViewModel.markStarted()
                    showsOnboarding = true
                }
            case .markCompletedSilently:
                await onboardingViewModel.finish()
            case .none:
                break
            }
            // 온보딩 예시 LA 정리 — **다음 앱 실행에서만**. 포그라운드 복귀 시점은 Face ID가
            // 잠금화면을 건너뛰어 "봤을 것"이라는 가정이 깨진다(게시 직후 정리돼 버림).
            // 같은 실행 동안은 계속 유지 → 다음 실행에 마커 기반으로 예시만 정리, 실행이
            // 없으면 8시간 뒤 시스템 자동 종료. 온보딩을 띄우는 실행은 건너뜀(진행 중 자산).
            if !showsOnboarding {
                await dependencies.endSampleLiveActivities()
            }
            await startAlwaysOnActivities(settingsViewModel.settings)
        }
        // 첫 실행 온보딩 — 전체 화면. 완료·스킵 시 커버를 닫고:
        // 1) 메모 탭 새로고침(온보딩이 첫 큐를 저장했을 수 있음)
        // 2) 게시했으면 그 LA를 메모 VM이 채택(버튼 상태·자동 갱신 동기)
        // 3) 설정 VM 재로드(완주 플래그가 낡은 스냅샷에 덮이지 않게)
        .fullScreenCover(isPresented: $showsOnboarding) {
            OnboardingView(viewModel: onboardingViewModel) {
                showsOnboarding = false
                Task {
                    await memoViewModel.onAppear()
                    if onboardingViewModel.published {
                        memoViewModel.adoptExternalLiveActivity()
                    }
                    await settingsViewModel.onAppear()
                    // 4) 항상 표시 재게시 — 재시청(설정) 경로에서 예시 게시가 실사용 일정·할일
                    //    LA를 대체했다가 방금 정리됐을 수 있다. 첫 실행 경로에선 기본 off라 no-op.
                    await startAlwaysOnActivities(settingsViewModel.settings)
                }
            }
        }
        // reconcile(강등 접어두기/재구독 복구)의 **단일 실행 지점** — 확정 판정이 바뀔 때마다
        // (콜드런치 첫 판정, 포그라운드 refresh, 페이월 구매·복원, 갱신·환불 스트림) 여기서만 돈다.
        // 다른 곳(scenePhase·cueApp)에서 병행 호출하면 같은 전이에 두 번 실행돼 fetch-modify-save가
        // 인터리브된다(리뷰 지적). 연속 전이는 직렬 체인으로 순서를 보장한다.
        .onChange(of: premiumStore.confirmedIsPremium) { _, confirmed in
            guard let confirmed else { return }
            reconcileChain = Task { [previous = reconcileChain] in
                await previous?.value
                if await dependencies.reconcilePremiumSettings(isPremium: confirmed) {
                    await dependencies.refreshLiveActivityLayout()
                    await settingsViewModel.onAppear()
                    await startAlwaysOnActivities(settingsViewModel.settings)
                }
            }
        }
        // 포그라운드 복귀 — 시스템이 8시간 후 LA를 종료했을 수 있어 다시 게시한다
        // (VM이 이 실행에서 켠 상태면 각자 건너뛴다 — 중복 게시 없음).
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                // 엔타이틀먼트 재확인을 **항상** — 구독·체험 만료는 시스템이 push해주지
                // 않아, 게이트 안에 두면 항상표시 꺼둔 사용자의 강등이 재시작까지 밀린다.
                // 판정이 바뀌면 위 onChange(confirmedIsPremium)가 reconcile을 돌린다 —
                // 여기서 병행 호출하면 같은 전이에 이중 실행이라 refresh만 한다.
                await premiumStore.refresh()
                await startAlwaysOnActivities(settingsViewModel.settings)
            }
        }
        // 설정에서 항상 표시(또는 항목)를 켜는 순간 즉시 게시 — 꺼짐 방향은 건드리지 않는다
        // (사용자가 수동으로 띄운 LA를 죽이지 않기 위해).
        .onChange(of: settingsViewModel.settings) { old, new in
            // 설정에서 숨김 목록이 바뀌면 할일 화면·칩바에 즉시 반영.
            if old.hiddenReminderListIDs != new.hiddenReminderListIDs {
                reminderViewModel.applyHiddenReminderLists(new.hiddenReminderListIDs)
            }
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

    /// 항상 표시 설정에 따라 선택된 항목의 LA를 자동 게시한다 — 각 VM이 중복·권한·빈 데이터·
    /// **Premium 여부**를 거른다. 콜드런치에 `start()`(cueApp)보다 먼저 돌 수 있어, 게시 전
    /// 엔타이틀먼트를 직접 새로고침해 프리미엄 사용자의 첫 게시가 레이스로 빠지지 않게 한다.
    private func startAlwaysOnActivities(_ settings: AppSettings) async {
        guard settings.liveAlwaysOn else { return }
        await premiumStore.refresh()
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
        case .settings:
            // 온보딩 다시 보기 — 첫 실행과 같은 커버를 재사용하되 진행 상태만 초기화한다.
            SettingsView(viewModel: settingsViewModel) {
                onboardingViewModel.reset()
                showsOnboarding = true
            }
        }
    }
}

#Preview {
    RootView(dependencies: .preview, premiumStore: PremiumStore(service: DisabledPurchaseService()))
}
