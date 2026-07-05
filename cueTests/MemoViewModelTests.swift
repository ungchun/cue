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
        memo: Memo = .default
    ) -> (MemoViewModel, InMemoryMemoRepository, RecordingMemoLiveActivity) {
        let repo = InMemoryMemoRepository(memo: memo)
        let service = RecordingMemoLiveActivity()
        var deps = Dependencies.preview
        deps.fetchMemo = FetchMemoUseCase(repository: repo)
        deps.saveMemo = SaveMemoUseCase(repository: repo)
        deps.startMemoLiveActivity = StartMemoLiveActivityUseCase(service: service)
        deps.endMemoLiveActivity = EndMemoLiveActivityUseCase(service: service)
        return (MemoViewModel(dependencies: deps), repo, service)
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

    // MARK: - 저장

    @Test func setTextPersistsMemo() async {
        let (viewModel, repo, _) = makeViewModel()

        await viewModel.setText("새 메모")

        #expect(await repo.fetch().text == "새 메모")
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

    func startReminder(listTitle: String, items: [LiveReminderItem], remaining: Int, todayCount: Int) async throws {}
    func endReminder() async {}
    func startSchedule(days: [LiveScheduleDay], todayCount: Int) async throws {}
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
