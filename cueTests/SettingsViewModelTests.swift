//
//  SettingsViewModelTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

@MainActor
struct SettingsViewModelTests {

    /// 인메모리 저장소를 주입한 ViewModel을 만든다. `Dependencies`는 struct(var 필드)라
    /// `.preview`에서 AppSettings 관련 use case 둘만 갈아끼운다.
    private func makeViewModel(
        repository: InMemoryAppSettingsRepository
    ) -> SettingsViewModel {
        var dependencies = Dependencies.preview
        dependencies.fetchAppSettings = FetchAppSettingsUseCase(repository: repository)
        dependencies.saveAppSettings = SaveAppSettingsUseCase(repository: repository)
        return SettingsViewModel(dependencies: dependencies)
    }

    /// onAppear는 저장된 설정을 불러온다.
    @Test func onAppearLoadsPersistedSettings() async {
        var stored = AppSettings.default
        stored.colorScheme = .dark
        let repository = InMemoryAppSettingsRepository(storage: stored)
        let viewModel = makeViewModel(repository: repository)

        await viewModel.onAppear()

        #expect(viewModel.settings.colorScheme == .dark)
    }

    /// 로드 전 기본 상태는 .default(시스템 테마).
    @Test func startsAtDefaultBeforeLoad() {
        let viewModel = makeViewModel(repository: InMemoryAppSettingsRepository())
        #expect(viewModel.settings == .default)
    }

    /// 화면 모드 변경은 메모리에 즉시 반영되고 영속 저장된다 —
    /// 같은 저장소로 새 ViewModel을 로드해도 바뀐 값이 보인다.
    @Test func setColorSchemePersists() async {
        let repository = InMemoryAppSettingsRepository()
        let viewModel = makeViewModel(repository: repository)
        await viewModel.onAppear()

        await viewModel.setColorScheme(.light)
        #expect(viewModel.settings.colorScheme == .light)

        let reloaded = makeViewModel(repository: repository)
        await reloaded.onAppear()
        #expect(reloaded.settings.colorScheme == .light)
    }

    /// 시작 탭 변경이 영속화된다.
    @Test func setStartTabPersists() async {
        let repository = InMemoryAppSettingsRepository()
        let viewModel = makeViewModel(repository: repository)
        await viewModel.onAppear()

        await viewModel.setStartTabID("memo")
        #expect(viewModel.settings.startTabID == "memo")

        let reloaded = makeViewModel(repository: repository)
        await reloaded.onAppear()
        #expect(reloaded.settings.startTabID == "memo")
    }

    /// 집중 종료 소리 토글이 영속화된다.
    @Test func setFocusEndSoundPersists() async {
        let repository = InMemoryAppSettingsRepository()
        let viewModel = makeViewModel(repository: repository)
        await viewModel.onAppear()

        await viewModel.setFocusEndSound(true)
        #expect(viewModel.settings.focusEndSound == true)

        let reloaded = makeViewModel(repository: repository)
        await reloaded.onAppear()
        #expect(reloaded.settings.focusEndSound == true)
    }

    /// onAppear는 저장된 메모 색을 불러온다 — 설정 탭이 메모 LA 색의 편집면.
    @Test func onAppearLoadsMemoColor() async {
        let memoRepo = InMemoryMemoRepository(memo: Memo(text: "x", colorHex: "#FF3B30"))
        var deps = Dependencies.preview
        deps.fetchMemo = FetchMemoUseCase(repository: memoRepo)
        let viewModel = SettingsViewModel(dependencies: deps)

        await viewModel.onAppear()

        #expect(viewModel.memoColorHex == "#FF3B30")
    }

    /// 메모 LA 색 변경은 메모에 영속화되고, 텍스트는 덮어쓰지 않는다.
    @Test func setMemoColorPersistsAndKeepsText() async {
        let memoRepo = InMemoryMemoRepository(memo: Memo(text: "기억", colorHex: "#000000"))
        var deps = Dependencies.preview
        deps.fetchMemo = FetchMemoUseCase(repository: memoRepo)
        deps.saveMemo = SaveMemoUseCase(repository: memoRepo)
        let viewModel = SettingsViewModel(dependencies: deps)
        await viewModel.onAppear()

        await viewModel.setMemoColor("#34C759")

        #expect(viewModel.memoColorHex == "#34C759")
        let saved = await memoRepo.fetch()
        #expect(saved.colorHex == "#34C759")
        #expect(saved.text == "기억")
    }

    /// 메모 LA 글자색 변경은 메모에 영속화되고, 배경색·텍스트는 덮어쓰지 않는다.
    @Test func setMemoTextColorPersistsAndKeepsOthers() async {
        let memoRepo = InMemoryMemoRepository(
            memo: Memo(text: "기억", colorHex: "#000000", textColorHex: "#FFFFFF")
        )
        var deps = Dependencies.preview
        deps.fetchMemo = FetchMemoUseCase(repository: memoRepo)
        deps.saveMemo = SaveMemoUseCase(repository: memoRepo)
        let viewModel = SettingsViewModel(dependencies: deps)
        await viewModel.onAppear()

        await viewModel.setMemoTextColor("#FFCC00")

        #expect(viewModel.memoTextColorHex == "#FFCC00")
        let saved = await memoRepo.fetch()
        #expect(saved.textColorHex == "#FFCC00")
        #expect(saved.colorHex == "#000000")
        #expect(saved.text == "기억")
    }

    /// 메모 글자 크기가 영속화된다.
    @Test func setMemoTextSizePersists() async {
        let repository = InMemoryAppSettingsRepository()
        let viewModel = makeViewModel(repository: repository)
        await viewModel.onAppear()

        await viewModel.setMemoTextSize(.small)

        let reloaded = makeViewModel(repository: repository)
        await reloaded.onAppear()
        #expect(reloaded.settings.memoTextSize == .small)
    }

    /// 메모 캘린더 표시 플래그가 영속화된다.
    @Test func setMemoShowsCalendarPersists() async {
        let repository = InMemoryAppSettingsRepository()
        let viewModel = makeViewModel(repository: repository)
        await viewModel.onAppear()

        await viewModel.setMemoShowsCalendar(true)

        let reloaded = makeViewModel(repository: repository)
        await reloaded.onAppear()
        #expect(reloaded.settings.memoShowsCalendar == true)
    }

    /// 일정 캘린더 표시 플래그가 영속화된다.
    @Test func setScheduleShowsCalendarPersists() async {
        let repository = InMemoryAppSettingsRepository()
        let viewModel = makeViewModel(repository: repository)
        await viewModel.onAppear()

        await viewModel.setScheduleShowsCalendar(true)

        let reloaded = makeViewModel(repository: repository)
        await reloaded.onAppear()
        #expect(reloaded.settings.scheduleShowsCalendar == true)
    }

    /// 라이브 항상 표시 마스터 토글이 영속화된다.
    @Test func setLiveAlwaysOnPersists() async {
        let repository = InMemoryAppSettingsRepository()
        let viewModel = makeViewModel(repository: repository)
        await viewModel.onAppear()

        await viewModel.setLiveAlwaysOn(true)

        let reloaded = makeViewModel(repository: repository)
        await reloaded.onAppear()
        #expect(reloaded.settings.liveAlwaysOn == true)
        // 하위 종류 기본값은 셋 다 on.
        #expect(reloaded.settings.liveAlwaysOnMemo == true)
        #expect(reloaded.settings.liveAlwaysOnReminder == true)
        #expect(reloaded.settings.liveAlwaysOnSchedule == true)
    }

    /// 하위 종류를 마지막 하나까지 끄면 마스터도 함께 꺼진다(빈 활성 상태 방지).
    @Test func turningOffLastKindTurnsMasterOff() async {
        let repository = InMemoryAppSettingsRepository()
        let viewModel = makeViewModel(repository: repository)
        await viewModel.onAppear()
        await viewModel.setLiveAlwaysOn(true)

        await viewModel.setLiveAlwaysOnMemo(false)
        await viewModel.setLiveAlwaysOnReminder(false)
        #expect(viewModel.settings.liveAlwaysOn == true)   // 아직 일정이 남음

        await viewModel.setLiveAlwaysOnSchedule(false)
        #expect(viewModel.settings.liveAlwaysOn == false)  // 셋 다 꺼짐 → 마스터 off
    }

    /// 셋 다 꺼진 채 접힌 뒤 마스터를 다시 켜면 하위가 셋 다 on으로 리셋된다
    /// (켜자마자 다시 접히는 불능 상태 방지).
    @Test func reenablingMasterResetsKindsOn() async {
        let repository = InMemoryAppSettingsRepository()
        let viewModel = makeViewModel(repository: repository)
        await viewModel.onAppear()
        await viewModel.setLiveAlwaysOn(true)
        await viewModel.setLiveAlwaysOnMemo(false)
        await viewModel.setLiveAlwaysOnReminder(false)
        await viewModel.setLiveAlwaysOnSchedule(false)

        await viewModel.setLiveAlwaysOn(true)

        #expect(viewModel.settings.liveAlwaysOnMemo == true)
        #expect(viewModel.settings.liveAlwaysOnReminder == true)
        #expect(viewModel.settings.liveAlwaysOnSchedule == true)
    }

    /// 항상 표시 할일 범위가 영속화된다.
    @Test func setLiveAlwaysOnReminderScopePersists() async {
        let repository = InMemoryAppSettingsRepository()
        let viewModel = makeViewModel(repository: repository)
        await viewModel.onAppear()

        await viewModel.setLiveAlwaysOnReminderScopeID("today")

        let reloaded = makeViewModel(repository: repository)
        await reloaded.onAppear()
        #expect(reloaded.settings.liveAlwaysOnReminderScopeID == "today")
    }

    /// 캘린더 표시 토글은 켜져 있는 LA를 즉시 다시 그리게 한다 — 저장(App Group 미러) 후
    /// refreshLayout이 호출되어 위젯이 새 플래그를 렌더 시점에 읽는다.
    @Test func calendarTogglesRefreshLiveActivityLayout() async {
        let repository = InMemoryAppSettingsRepository()
        let service = RefreshRecordingLiveActivityService()
        var dependencies = Dependencies.preview
        dependencies.fetchAppSettings = FetchAppSettingsUseCase(repository: repository)
        dependencies.saveAppSettings = SaveAppSettingsUseCase(repository: repository)
        dependencies.refreshLiveActivityLayout = RefreshLiveActivityLayoutUseCase(service: service)
        let viewModel = SettingsViewModel(dependencies: dependencies)
        await viewModel.onAppear()

        await viewModel.setMemoShowsCalendar(true)
        await viewModel.setScheduleShowsCalendar(true)

        #expect(await service.refreshLayoutCount == 2)
    }
}

// MARK: - refreshLayout 기록용 더블 — 나머지 호출은 무시한다.

private final actor RefreshRecordingLiveActivityService: LiveActivityService {
    var isEnabled: Bool { true }

    private(set) var refreshLayoutCount = 0

    func startReminder(listTitle: String, items: [LiveReminderItem], remaining: Int, todayCount: Int) async throws {}
    func endReminder() async {}
    func startSchedule(days: [LiveScheduleDay], todayCount: Int) async throws {}
    func endSchedule() async {}
    func startMemo(text: String, colorHex: String, textColorHex: String) async throws {}
    func endMemo() async {}
    func sync() async {}
    func refreshLayout() async {
        refreshLayoutCount += 1
    }
}
