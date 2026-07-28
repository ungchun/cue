//
//  ConsiderReviewPromptUseCaseTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct ConsiderReviewPromptUseCaseTests {

    /// 테스트에서 날짜를 고정하기 위한 헬퍼 — 같은 달력으로 use case에 넘긴다.
    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Date(timeIntervalSince1970: 1_700_000_000))!
    }

    /// 같은 날 여러 번 게시해도 사용일은 1만 오른다 — 프리미엄이 하루에 문턱을 채우지 못하게 하는 핵심.
    @Test func sameDayCountsOnce() async {
        let repository = InMemoryReviewPromptStateRepository()
        let considerReviewPrompt = ConsiderReviewPromptUseCase(repository: repository)

        for _ in 0..<10 {
            _ = await considerReviewPrompt(now: day(0))
        }

        #expect(await repository.fetch().usageDayCount == 1)
    }

    /// 서로 다른 날은 각각 센다. 4일째에 처음으로 요청한다.
    @Test func promptsOnFourthDistinctDay() async {
        let repository = InMemoryReviewPromptStateRepository()
        let considerReviewPrompt = ConsiderReviewPromptUseCase(repository: repository)

        #expect(await considerReviewPrompt(now: day(0)) == false)   // 1일
        #expect(await considerReviewPrompt(now: day(1)) == false)   // 2일
        #expect(await considerReviewPrompt(now: day(2)) == false)   // 3일
        #expect(await considerReviewPrompt(now: day(3)) == true)    // 4일 → 요청
        #expect(await repository.fetch().usageDayCount == 4)
    }

    /// 날짜가 연속일 필요는 없다 — 띄엄띄엄 써도 누적 4일이면 요청한다.
    @Test func daysNeedNotBeConsecutive() async {
        let repository = InMemoryReviewPromptStateRepository()
        let considerReviewPrompt = ConsiderReviewPromptUseCase(repository: repository)

        #expect(await considerReviewPrompt(now: day(0)) == false)
        #expect(await considerReviewPrompt(now: day(5)) == false)
        #expect(await considerReviewPrompt(now: day(30)) == false)
        #expect(await considerReviewPrompt(now: day(100)) == true)
    }

    /// 한 번 요청한 뒤로는 계속 써도 다시 요청하지 않는다 — 평생 1회.
    @Test func doesNotPromptAgainAfterFiring() async {
        let repository = InMemoryReviewPromptStateRepository()
        let considerReviewPrompt = ConsiderReviewPromptUseCase(repository: repository)

        for offset in 0...3 { _ = await considerReviewPrompt(now: day(offset)) }
        #expect(await repository.fetch().promptedThresholds == [4])

        for offset in 4...20 {
            #expect(await considerReviewPrompt(now: day(offset)) == false)
        }
    }

    /// 4일째를 놓쳐도(그날 게시가 없어 호출되지 않음) 다음 사용일에 만회한다 —
    /// `== 4`가 아니라 `>= 4`로 판정하는 이유. 놓친 문턱이 영구히 사라지면 안 된다.
    @Test func recoversWhenExactThresholdDayIsMissed() async {
        // 이미 5일을 쓴 상태인데 아직 요청한 적이 없는 저장본(문턱 도달 순간을 놓친 케이스).
        let repository = InMemoryReviewPromptStateRepository(
            storage: ReviewPromptState(usageDayCount: 5, lastDayKey: "past")
        )
        let considerReviewPrompt = ConsiderReviewPromptUseCase(repository: repository)

        #expect(await considerReviewPrompt(now: day(0)) == true)
    }

    /// 요청하지 않은 호출에서도 날짜 진행은 저장된다 — 저장을 빠뜨리면 같은 날을 계속 다시 센다.
    @Test func persistsDayProgressEvenWhenNotPrompting() async {
        let repository = InMemoryReviewPromptStateRepository()
        let considerReviewPrompt = ConsiderReviewPromptUseCase(repository: repository)

        _ = await considerReviewPrompt(now: day(0))

        let saved = await repository.fetch()
        #expect(saved.usageDayCount == 1)
        #expect(saved.lastDayKey != nil)
    }
}
