//
//  MemoViewModelTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

@MainActor
struct MemoViewModelTests {

    /// `.preview` 의존성을 복제해 메모 관련 use case만 테스트용으로 교체한다 — 전체 조립을
    /// 반복하지 않고 메모 경로만 격리해 검증.
    private func makeViewModel(
        memo: Memo = .default,
        quotaRepository: InMemoryLiveActivationQuotaRepository = InMemoryLiveActivationQuotaRepository(),
        isPremium: Bool = false
    ) -> (MemoViewModel, InMemoryMemoRepository, RecordingMemoLiveActivity) {
        let repo = InMemoryMemoRepository(memo: memo)
        let service = RecordingMemoLiveActivity()
        var deps = Dependencies.preview
        deps.fetchMemo = FetchMemoUseCase(repository: repo)
        deps.saveMemo = SaveMemoUseCase(repository: repo)
        deps.startMemoLiveActivity = StartMemoLiveActivityUseCase(service: service)
        deps.endMemoLiveActivity = EndMemoLiveActivityUseCase(service: service)
        deps.consumeLiveActivation = ConsumeLiveActivationUseCase(repository: quotaRepository)
        let viewModel = MemoViewModel(dependencies: deps, premiumStore: PremiumStore(previewIsPremium: isPremium))
        return (viewModel, repo, service)
    }

    /// 오늘 사용량이 이미 `used`인 쿼터 저장소.
    private func quotaRepository(used: Int) -> InMemoryLiveActivationQuotaRepository {
        InMemoryLiveActivationQuotaRepository(
            storage: LiveActivationQuota(dayKey: ConsumeLiveActivationUseCase.dayKey(for: .now), used: used)
        )
    }

    // MARK: - 로드

    @Test func onAppearLoadsSavedMemo() async {
        let (viewModel, _, _) = makeViewModel(memo: Memo(text: "기억할 것", colorHex: "#34C759"))

        await viewModel.onAppear()

        #expect(viewModel.memo.text == "기억할 것")
        #expect(viewModel.memo.colorHex == "#34C759")
    }

    /// onAppear는 메모 글자 크기 설정을 읽어 VM에 반영한다 — View가 이 값으로 글꼴 크기를 정한다.
    @Test func onAppearLoadsMemoTextSizeFromSettings() async {
        var stored = AppSettings.default
        stored.memoTextSize = .small
        let repo = InMemoryMemoRepository(memo: .default)
        var deps = Dependencies.preview
        deps.fetchMemo = FetchMemoUseCase(repository: repo)
        deps.fetchAppSettings = FetchAppSettingsUseCase(
            repository: InMemoryAppSettingsRepository(storage: stored)
        )
        let viewModel = MemoViewModel(dependencies: deps)

        await viewModel.onAppear()

        #expect(viewModel.textSize == .small)
    }

    // MARK: - canStartLiveActivity (버튼 활성 기준)

    @Test func cannotStartWhenTextEmpty() {
        let (viewModel, _, _) = makeViewModel(memo: .default)
        #expect(viewModel.canStartLiveActivity == false)
    }

    @Test func cannotStartWhenTextWhitespaceOnly() async {
        let (viewModel, _, _) = makeViewModel()
        await viewModel.setText("   ")
        #expect(viewModel.canStartLiveActivity == false)
    }

    @Test func canStartWhenTextPresent() async {
        let (viewModel, _, _) = makeViewModel()
        await viewModel.setText("할 수 있다")
        #expect(viewModel.canStartLiveActivity == true)
    }

    // MARK: - 토글

    @Test func toggleStartsLiveActivityWhenTextPresent() async {
        let (viewModel, _, service) = makeViewModel(memo: Memo(text: "나 오늘 할 수 있다", colorHex: "#FF3B30"))
        await viewModel.onAppear()

        await viewModel.toggleLiveActivity()

        #expect(viewModel.liveActivityActive == true)
        #expect(await service.startMemoCalls.count == 1)
        #expect(await service.startMemoCalls.first?.text == "나 오늘 할 수 있다")
    }

    /// 떠 있을 때 다시 누르면 끄지 않고 **끄고 다시 켠다(새로고침)** — 활성 유지, end 1회 + start 2회.
    @Test func toggleAgainRestartsLiveActivity() async {
        let (viewModel, _, service) = makeViewModel(memo: Memo(text: "할 일", colorHex: "#FF3B30"))
        await viewModel.onAppear()

        await viewModel.toggleLiveActivity()   // 시작
        await viewModel.toggleLiveActivity()   // 끄고 다시 켜기(새로고침)

        #expect(viewModel.liveActivityActive == true)
        #expect(await service.endMemoCount == 1)
        #expect(await service.startMemoCalls.count == 2)
    }

    @Test func toggleDoesNothingWhenTextEmpty() async {
        let (viewModel, _, service) = makeViewModel(memo: .default)

        await viewModel.toggleLiveActivity()

        #expect(viewModel.liveActivityActive == false)
        #expect(await service.startMemoCalls.isEmpty)
    }

    // MARK: - 항상 표시 자동 게시

    /// 항상 표시 자동 게시는 사용자 탭이 아니므로 쿼터를 소비하지 않는다 — 한도 소진 상태여도 게시.
    @Test func alwaysOnStartsWithoutConsumingQuota() async {
        let (viewModel, _, service) = makeViewModel(
            memo: Memo(text: "메모", colorHex: "#FF3B30"),
            quotaRepository: quotaRepository(used: 2)
        )

        await viewModel.startAlwaysOnLiveActivity()

        #expect(viewModel.liveActivityActive == true)
        #expect(await service.startMemoCalls.count == 1)
    }

    /// 빈 메모는 자동 게시 대상이 아니다.
    @Test func alwaysOnSkipsWhenTextEmpty() async {
        let (viewModel, _, service) = makeViewModel(memo: .init(text: "   ", colorHex: "#FF3B30"))

        await viewModel.startAlwaysOnLiveActivity()

        #expect(viewModel.liveActivityActive == false)
        #expect(await service.startMemoCalls.isEmpty)
    }

    /// 이미 활성(이 실행에서 켜짐)이면 중복 게시하지 않는다 — 포그라운드 복귀마다 재시작 방지.
    @Test func alwaysOnSkipsWhenAlreadyActive() async {
        let (viewModel, _, service) = makeViewModel(memo: Memo(text: "메모", colorHex: "#FF3B30"))
        await viewModel.onAppear()
        await viewModel.toggleLiveActivity()

        await viewModel.startAlwaysOnLiveActivity()

        #expect(await service.startMemoCalls.count == 1)
    }

    /// 하루 한도 안이면 소비하고 잔여를 돌려준다 — 뷰가 "1/2" 토스트를 띄우는 근거.
    @Test func toggleConsumesQuotaAndReturnsRemaining() async {
        let (viewModel, _, service) = makeViewModel(memo: Memo(text: "메모", colorHex: "#FF3B30"))
        await viewModel.onAppear()

        let verdict = await viewModel.toggleLiveActivity()

        #expect(verdict == .allowed(remaining: 1))
        #expect(viewModel.liveActivityActive == true)
        #expect(await service.startMemoCalls.count == 1)
    }

    /// Premium(무제한)이면 쿼터 소비 없이 그대로 LA를 켠다 — `.unlimited`도 시작 경로를 통과해야 한다.
    /// (설정 "라이브 항상 표시"와 무관하게 켜기 버튼은 동작해야 한다.)
    @Test func togglePremiumUserStartsLiveActivity() async {
        let (viewModel, _, service) = makeViewModel(
            memo: Memo(text: "메모", colorHex: "#FF3B30"),
            isPremium: true
        )
        await viewModel.onAppear()

        let verdict = await viewModel.toggleLiveActivity()

        #expect(verdict == .unlimited)
        #expect(viewModel.liveActivityActive == true)
        #expect(await service.startMemoCalls.count == 1)
    }

    /// 오늘 한도(2회)를 다 썼으면 거부 — LA를 시작하지 않고, 떠 있던 LA도 건드리지 않는다.
    @Test func toggleDeniedWhenQuotaExhausted() async {
        let (viewModel, _, service) = makeViewModel(
            memo: Memo(text: "메모", colorHex: "#FF3B30"),
            quotaRepository: quotaRepository(used: 2)
        )
        await viewModel.onAppear()

        let verdict = await viewModel.toggleLiveActivity()

        #expect(verdict == .denied)
        #expect(viewModel.liveActivityActive == false)
        #expect(await service.startMemoCalls.isEmpty)
        #expect(await service.endMemoCount == 0)   // 기존 LA를 죽이지 않는다
    }

    // MARK: - 저장

    @Test func setTextPersistsMemo() async {
        let (viewModel, repo, _) = makeViewModel()

        await viewModel.setText("새 메모")

        #expect(await repo.fetch().text == "새 메모")
    }

    /// 입력 상한 — LA 상한(120)과 동일하게 잘라 저장한다("적은 만큼 다 보인다" 보장).
    @Test func setTextCapsAtMaxLength() async {
        let (viewModel, repo, _) = makeViewModel()
        let long = String(repeating: "가", count: 130)

        await viewModel.setText(long)

        #expect(viewModel.memo.text.count == MemoViewModel.maxTextLength)
        #expect(await repo.fetch().text == String(repeating: "가", count: MemoViewModel.maxTextLength))
    }

    /// 정확히 상한 길이면 자르지 않는다.
    @Test func setTextKeepsTextAtExactLimit() async {
        let (viewModel, repo, _) = makeViewModel()
        let exact = String(repeating: "a", count: MemoViewModel.maxTextLength)

        await viewModel.setText(exact)

        #expect(await repo.fetch().text == exact)
    }

    @Test func setColorPersistsMemo() async {
        let (viewModel, repo, _) = makeViewModel(memo: Memo(text: "메모", colorHex: "#FF3B30"))

        await viewModel.setColor("#000000")

        #expect(await repo.fetch().colorHex == "#000000")
    }

    // MARK: - 활성 중 텍스트 변경

    @Test func clearingTextWhileActiveEndsLiveActivity() async {
        let (viewModel, _, service) = makeViewModel(memo: Memo(text: "할 일", colorHex: "#FF3B30"))
        await viewModel.onAppear()
        await viewModel.toggleLiveActivity()
        #expect(viewModel.liveActivityActive == true)

        await viewModel.setText("")

        #expect(viewModel.liveActivityActive == false)
        #expect(await service.endMemoCount == 1)
    }

    @Test func editingTextWhileActiveUpdatesLiveActivity() async {
        let (viewModel, _, service) = makeViewModel(memo: Memo(text: "처음", colorHex: "#FF3B30"))
        await viewModel.onAppear()
        await viewModel.toggleLiveActivity()

        await viewModel.setText("바뀐 메모")

        // 시작 1회 + 텍스트 변경 반영 1회 = 2회, 마지막 텍스트가 반영.
        #expect(await service.startMemoCalls.count == 2)
        #expect(await service.startMemoCalls.last?.text == "바뀐 메모")
        #expect(viewModel.liveActivityActive == true)
    }
}

// MARK: - 메모 LA 호출 기록용 더블

private actor RecordingMemoLiveActivity: LiveActivityService {
    var isEnabled: Bool { true }

    private(set) var startMemoCalls: [(text: String, colorHex: String, textColorHex: String)] = []
    private(set) var endMemoCount = 0

    func startReminder(listTitle: String, items: [LiveReminderItem], remaining: Int, todayCount: Int, weekEventDots: [LiveDayEventDots]) async throws {}
    func endReminder() async {}
    func startSchedule(days: [LiveScheduleDay], todayCount: Int, weekEventDots: [LiveDayEventDots]) async throws {}
    func endSchedule() async {}
    func startMemo(text: String, colorHex: String, textColorHex: String) async throws {
        startMemoCalls.append((text, colorHex, textColorHex))
    }
    func endMemo() async {
        endMemoCount += 1
    }
    func sync() async {}
    func refreshLayout() async {}
}
