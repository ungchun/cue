//
//  MemoUseCaseTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct MemoUseCaseTests {

    // MARK: - StartMemo — 빈 텍스트 검증

    @Test func startMemoWithEmptyTextThrowsAndDoesNotCallService() async {
        let service = RecordingMemoLiveActivity()

        await #expect(throws: DomainError.self) {
            try await StartMemoLiveActivityUseCase(service: service)(
                Memo(text: "", colorHex: "#FF3B30")
            )
        }
        #expect(await service.startMemoCalls.isEmpty)
    }

    @Test func startMemoWithWhitespaceOnlyThrows() async {
        let service = RecordingMemoLiveActivity()

        await #expect(throws: DomainError.self) {
            try await StartMemoLiveActivityUseCase(service: service)(
                Memo(text: "   \n\t ", colorHex: "#FF3B30")
            )
        }
        #expect(await service.startMemoCalls.isEmpty)
    }

    // MARK: - StartMemo — 트림 + forwarding + 길이 제한

    @Test func startMemoTrimsWhitespaceAndForwardsTextAndColor() async throws {
        let service = RecordingMemoLiveActivity()

        try await StartMemoLiveActivityUseCase(service: service)(
            Memo(text: "  나 오늘 할 수 있다  ", colorHex: "#0A84FF", textColorHex: "#FFCC00")
        )

        let call = try #require(await service.startMemoCalls.first)
        #expect(call.text == "나 오늘 할 수 있다")
        #expect(call.colorHex == "#0A84FF")
        #expect(call.textColorHex == "#FFCC00")
    }

    @Test func startMemoCapsLongTextAtMaxLength() async throws {
        let service = RecordingMemoLiveActivity()
        let long = String(repeating: "가", count: 300)

        try await StartMemoLiveActivityUseCase(service: service)(
            Memo(text: long, colorHex: "#FF3B30")
        )

        let call = try #require(await service.startMemoCalls.first)
        #expect(call.text.count == StartMemoLiveActivityUseCase.maxTextLength)
    }

    // MARK: - EndMemo — forwarding

    @Test func endMemoCallsServiceOnce() async {
        let service = RecordingMemoLiveActivity()

        await EndMemoLiveActivityUseCase(service: service)()

        #expect(await service.endMemoCount == 1)
    }

    // MARK: - Fetch / Save (인메모리 repo)

    @Test func fetchReturnsDefaultWhenNothingSaved() async {
        let repo = InMemoryMemoRepository()

        let memo = await FetchMemoUseCase(repository: repo)()

        #expect(memo == Memo.default)
    }

    @Test func saveThenFetchRoundTrips() async {
        let repo = InMemoryMemoRepository()
        let memo = Memo(text: "기억할 것", colorHex: "#34C759", textColorHex: "#FFCC00")

        await SaveMemoUseCase(repository: repo)(memo)
        let loaded = await FetchMemoUseCase(repository: repo)()

        #expect(loaded == memo)
    }

    // MARK: - 전방 호환 디코딩

    /// `textColorHex` 키가 없는 옛 JSON도 디코딩되어 흰색으로 채워진다 — 기존 저장본 보존.
    @Test func decodesLegacyMemoWithoutTextColor() throws {
        let legacy = Data(##"{"text":"옛 메모","colorHex":"#123456"}"##.utf8)

        let memo = try JSONDecoder().decode(Memo.self, from: legacy)

        #expect(memo.text == "옛 메모")
        #expect(memo.colorHex == "#123456")
        #expect(memo.textColorHex == "#FFFFFF")
    }
}

// MARK: - 메모 LA 호출 기록용 더블

private actor RecordingMemoLiveActivity: LiveActivityService {
    var isEnabled: Bool { true }

    private(set) var startMemoCalls: [(text: String, colorHex: String, textColorHex: String)] = []
    private(set) var endMemoCount = 0

    func startReminder(listTitle: String, items: [LiveReminderItem], remaining: Int, todayCount: Int, weekEventDots: [LiveDayEventDots]) async throws {}
    func endReminder() async {}
    func startSchedule(days: [LiveScheduleDay], todayCount: Int, weekEventDots: [LiveDayEventDots], showsCalendarOverride: Bool?) async throws {}
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
