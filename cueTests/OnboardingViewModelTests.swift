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

    func startReminder(listTitle: String, items: [LiveReminderItem], remaining: Int, todayCount: Int, weekEventDots: [LiveDayEventDots]) async throws {}
    func endReminder() async {}
    func startSchedule(days: [LiveScheduleDay], todayCount: Int, weekEventDots: [LiveDayEventDots]) async throws {}
    func endSchedule() async {}
    func startMemo(text: String, colorHex: String, textColorHex: String) async throws {
        if startFails { throw DomainError.validation("test") }
        startMemoCalls.append((text, colorHex, textColorHex))
    }
    func endMemo() async {}
    func sync() async {}
    func refreshLayout() async {}
}
