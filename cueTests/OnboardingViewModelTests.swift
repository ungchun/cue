//
//  OnboardingViewModelTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

@MainActor
struct OnboardingViewModelTests {

    /// `.preview` 의존성에서 온보딩이 만지는 경로(메모 저장·메모 LA·앱 설정)만 교체한다.
    private func makeViewModel(
        memo: Memo = .default,
        settings: AppSettings = .default
    ) -> (OnboardingViewModel, InMemoryMemoRepository, RecordingOnboardingLiveActivity, InMemoryAppSettingsRepository) {
        let memoRepo = InMemoryMemoRepository(memo: memo)
        let service = RecordingOnboardingLiveActivity()
        let settingsRepo = InMemoryAppSettingsRepository(storage: settings)
        var deps = Dependencies.preview
        deps.fetchMemo = FetchMemoUseCase(repository: memoRepo)
        deps.saveMemo = SaveMemoUseCase(repository: memoRepo)
        deps.startMemoLiveActivity = StartMemoLiveActivityUseCase(service: service)
        deps.startSampleLiveActivities = StartSampleLiveActivitiesUseCase(
            startSchedule: StartScheduleLiveActivityUseCase(service: service),
            startReminder: StartReminderLiveActivityUseCase(service: service)
        )
        deps.endScheduleLiveActivity = EndScheduleLiveActivityUseCase(service: service)
        deps.endReminderLiveActivity = EndReminderLiveActivityUseCase(service: service)
        deps.fetchAppSettings = FetchAppSettingsUseCase(repository: settingsRepo)
        deps.saveAppSettings = SaveAppSettingsUseCase(repository: settingsRepo)
        return (OnboardingViewModel(dependencies: deps), memoRepo, service, settingsRepo)
    }

    // MARK: - canPublish (버튼 활성 기준)

    @Test func cannotPublishWhenTextEmpty() {
        let (viewModel, _, _, _) = makeViewModel()
        #expect(viewModel.canPublish == false)
    }

    @Test func cannotPublishWhenTextWhitespaceOnly() {
        let (viewModel, _, _, _) = makeViewModel()
        viewModel.text = "   \n"
        #expect(viewModel.canPublish == false)
    }

    @Test func canPublishWhenTextPresent() {
        let (viewModel, _, _, _) = makeViewModel()
        viewModel.text = "우유 사기"
        #expect(viewModel.canPublish)
    }

    // MARK: - publish (첫 큐 띄우기)

    /// 입력한 텍스트로 메모를 저장하고 LA를 게시한다 — 기존 메모의 색은 보존한다
    /// (온보딩은 텍스트만 만지고 커스터마이징은 설정의 영역).
    @Test func publishSavesMemoPreservingColorsAndStartsLiveActivity() async {
        let seeded = Memo(text: "", colorHex: "#112233", textColorHex: "#AABBCC")
        let (viewModel, memoRepo, service, _) = makeViewModel(memo: seeded)
        viewModel.text = "  우유 사기  "

        await viewModel.publish()

        let saved = await memoRepo.fetch()
        #expect(saved.text == "우유 사기")           // 앞뒤 공백은 정리해 저장
        #expect(saved.colorHex == "#112233")
        #expect(saved.textColorHex == "#AABBCC")
        let calls = await service.startMemoCalls
        #expect(calls.count == 1)
        #expect(calls.first?.text == "우유 사기")
        #expect(calls.first?.colorHex == "#112233")
        #expect(viewModel.published)
    }

    /// 빈 입력은 아무것도 하지 않는다 — 버튼이 비활성이라 평소엔 오지 않는 마지막 방어선.
    @Test func publishWithBlankTextDoesNothing() async {
        let (viewModel, memoRepo, service, _) = makeViewModel(
            memo: Memo(text: "기존 메모", colorHex: "#000000")
        )
        viewModel.text = "   "

        await viewModel.publish()

        let saved = await memoRepo.fetch()
        #expect(saved.text == "기존 메모")           // 기존 메모를 덮지 않는다
        let calls = await service.startMemoCalls
        #expect(calls.isEmpty)
        #expect(viewModel.published == false)
    }

    /// 게시 실패(LA 시작 throw)면 published로 넘어가지 않는다.
    @Test func publishFailureKeepsUnpublished() async {
        let (viewModel, _, service, _) = makeViewModel()
        await service.setStartFails(true)
        viewModel.text = "우유 사기"

        await viewModel.publish()

        #expect(viewModel.published == false)
    }

    // MARK: - 예시 일정·할일 LA (첫 큐와 함께 3카드 장면)

    /// 첫 큐 게시는 예시 일정·할일 LA도 함께 띄운다 — 권한·실데이터 없이 잠금화면
    /// 3카드 장면. 캘린더는 **할일 쪽에만**(일정 카드는 일정 목록만) 강제한다.
    @Test func publishAlsoStartsSampleScheduleAndTasks() async {
        let (viewModel, _, service, _) = makeViewModel()
        viewModel.text = "우유 사기"

        await viewModel.publish()

        let scheduleCalls = await service.startScheduleCalls
        #expect(scheduleCalls.count == 1)
        #expect(scheduleCalls.first?.showsCalendarOverride == false)
        let reminderCalls = await service.startReminderCalls
        #expect(reminderCalls.count == 1)
        #expect(reminderCalls.first?.showsCalendarOverride == true)
    }

    /// 메모 게시가 실패하면 예시도 안 띄운다 — 주인공(첫 큐) 없이 조연만 뜨는 잠금화면 방지.
    @Test func publishFailureSkipsSamples() async {
        let (viewModel, _, service, _) = makeViewModel()
        await service.setStartFails(true)
        viewModel.text = "우유 사기"

        await viewModel.publish()

        #expect(await service.startScheduleCalls.isEmpty)
        #expect(await service.startReminderCalls.isEmpty)
    }

    /// Done·Skip 마감 시 예시 일정·할일 LA를 종료한다 — 가짜 데이터가 잠금화면에
    /// 최대 8시간 남는 것을 방지. 메모(진짜 첫 큐)는 남긴다.
    @Test func endSampleLiveActivitiesEndsScheduleAndReminderOnly() async {
        let (viewModel, _, service, _) = makeViewModel()

        await viewModel.endSampleLiveActivities()

        #expect(await service.endScheduleCount == 1)
        #expect(await service.endReminderCount == 1)
        #expect(await service.endMemoCount == 0)
    }

    /// 조용한 완주 처리(기존 사용자 마이그레이션)는 finish만 부른다 — 이 경로에서
    /// LA를 종료하면 실사용 일정·할일 LA를 죽일 수 있으므로 finish는 저장만 해야 한다.
    @Test func finishAloneDoesNotEndAnyLiveActivity() async {
        let (viewModel, _, service, _) = makeViewModel()

        await viewModel.finish()

        #expect(await service.endScheduleCount == 0)
        #expect(await service.endReminderCount == 0)
    }

    // MARK: - launchDecision (앱 시작 시 온보딩 표시 판정)

    /// 이미 완주했으면 아무것도 안 한다 — 한 번 본 사람에겐 다시 안 뜬다.
    @Test func launchDecisionIsNoneWhenCompleted() {
        var settings = AppSettings.default
        settings.hasCompletedOnboarding = true
        #expect(OnboardingViewModel.launchDecision(settings: settings, hasPriorInstall: false) == .none)
        #expect(OnboardingViewModel.launchDecision(settings: settings, hasPriorInstall: true) == .none)
    }

    /// 미완주 + 기존 설치 흔적 = 업데이트로 넘어온 기존 사용자 — 온보딩 없이 조용히 완주 처리.
    @Test func launchDecisionMigratesExistingUserSilently() {
        #expect(OnboardingViewModel.launchDecision(settings: .default, hasPriorInstall: true) == .markCompletedSilently)
    }

    /// 온보딩을 **시작한 적 있는** 미완주 사용자는 흔적과 무관하게 이어서 다시 본다 —
    /// 온보딩 도중(첫 큐 게시가 메모를 저장한 뒤) 앱을 죽여도 기존 사용자로 오판하지 않는다.
    @Test func launchDecisionResumesWhenStartedButNotCompleted() {
        var settings = AppSettings.default
        settings.hasStartedOnboarding = true
        #expect(OnboardingViewModel.launchDecision(settings: settings, hasPriorInstall: true) == .show)
        #expect(OnboardingViewModel.launchDecision(settings: settings, hasPriorInstall: false) == .show)
    }

    /// 표시 직전 시작 마커 저장 — 다른 설정은 보존, 완주 뒤에는 다시 안 쓴다.
    @Test func markStartedPersistsFlagPreservingOtherSettings() async {
        var seeded = AppSettings.default
        seeded.startTabID = "focus"
        let (viewModel, _, _, settingsRepo) = makeViewModel(settings: seeded)

        await viewModel.markStarted()

        let saved = await settingsRepo.fetch()
        #expect(saved.hasStartedOnboarding)
        #expect(saved.startTabID == "focus")
    }

    /// 미완주 + 흔적 없음 = 진짜 신규 설치 — 온보딩 표시.
    @Test func launchDecisionShowsForFreshInstall() {
        #expect(OnboardingViewModel.launchDecision(settings: .default, hasPriorInstall: false) == .show)
    }

    // MARK: - finish (완료/스킵 공통)

    /// 완료·스킵 시 완주 플래그를 저장한다 — 다른 설정 값은 건드리지 않는다.
    @Test func finishPersistsCompletionFlagPreservingOtherSettings() async {
        var seeded = AppSettings.default
        seeded.startTabID = "focus"
        let (viewModel, _, _, settingsRepo) = makeViewModel(settings: seeded)

        await viewModel.finish()

        let saved = await settingsRepo.fetch()
        #expect(saved.hasCompletedOnboarding)
        #expect(saved.startTabID == "focus")
    }
}

// MARK: - 메모 LA 호출 기록용 더블 (온보딩 전용 — 실패 주입 지원)

private actor RecordingOnboardingLiveActivity: LiveActivityService {
    var isEnabled: Bool { true }

    private(set) var startMemoCalls: [(text: String, colorHex: String, textColorHex: String)] = []
    private var startFails = false

    func setStartFails(_ fails: Bool) { startFails = fails }

    private(set) var startReminderCalls: [(listTitle: String, items: [LiveReminderItem], showsCalendarOverride: Bool?)] = []
    private(set) var startScheduleCalls: [(days: [LiveScheduleDay], showsCalendarOverride: Bool?)] = []
    private(set) var endReminderCount = 0
    private(set) var endScheduleCount = 0
    private(set) var endMemoCount = 0

    func startReminder(listTitle: String, items: [LiveReminderItem], remaining: Int, todayCount: Int, weekEventDots: [LiveDayEventDots], showsCalendarOverride: Bool?) async throws {
        startReminderCalls.append((listTitle, items, showsCalendarOverride))
    }
    func endReminder() async { endReminderCount += 1 }
    func startSchedule(days: [LiveScheduleDay], todayCount: Int, weekEventDots: [LiveDayEventDots], showsCalendarOverride: Bool?) async throws {
        startScheduleCalls.append((days, showsCalendarOverride))
    }
    func endSchedule() async { endScheduleCount += 1 }
    func startMemo(text: String, colorHex: String, textColorHex: String) async throws {
        if startFails { throw DomainError.validation("test") }
        startMemoCalls.append((text, colorHex, textColorHex))
    }
    func endMemo() async { endMemoCount += 1 }
    func sync() async {}
    func refreshLayout() async {}
}
