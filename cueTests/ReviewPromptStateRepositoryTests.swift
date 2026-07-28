//
//  ReviewPromptStateRepositoryTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct ReviewPromptStateRepositoryTests {

    /// 저장·복원 왕복에서 모든 필드가 보존된다 — 여기가 날아가면 사용일이 리셋돼
    /// 리뷰를 영영 못 묻거나, 이미 물어본 문턱을 다시 물어본다.
    @Test func userDefaultsRoundTripsState() async {
        let defaults = UserDefaults(suiteName: "test.reviewPrompt.\(UUID().uuidString)")!
        let repo = UserDefaultsReviewPromptStateRepository(defaults: defaults)

        await repo.save(ReviewPromptState(usageDayCount: 3, lastDayKey: "2026-7-29", promptedThresholds: [4]))

        let fetched = await repo.fetch()
        #expect(fetched.usageDayCount == 3)
        #expect(fetched.lastDayKey == "2026-7-29")
        #expect(fetched.promptedThresholds == [4])
    }

    /// 저장값이 없으면 빈 상태 — 신규 설치는 0일부터 시작한다.
    @Test func fetchReturnsEmptyWhenNothingStored() async {
        let defaults = UserDefaults(suiteName: "test.reviewPrompt.\(UUID().uuidString)")!
        let repo = UserDefaultsReviewPromptStateRepository(defaults: defaults)

        #expect(await repo.fetch() == .empty)
        #expect(ReviewPromptState.empty.usageDayCount == 0)
        #expect(ReviewPromptState.empty.promptedThresholds.isEmpty)
    }

    /// 깨진 데이터면 빈 상태로 폴백한다 — 리뷰 판정 때문에 앱이 죽지 않는다.
    @Test func fetchReturnsEmptyOnCorruptData() async {
        let defaults = UserDefaults(suiteName: "test.reviewPrompt.\(UUID().uuidString)")!
        defaults.set(Data("not json".utf8), forKey: "cue.reviewPromptState.v1")
        let repo = UserDefaultsReviewPromptStateRepository(defaults: defaults)

        #expect(await repo.fetch() == .empty)
    }

    /// 전방 호환 디코딩 — 필드가 없던 옛 저장본도 기본값으로 채워 살아난다.
    @Test func decodesForwardCompatiblyFillingMissingKeys() throws {
        let state = try JSONDecoder().decode(ReviewPromptState.self, from: Data("{}".utf8))
        #expect(state == .empty)

        let partial = try JSONDecoder().decode(
            ReviewPromptState.self,
            from: Data(#"{"usageDayCount":2}"#.utf8)
        )
        #expect(partial.usageDayCount == 2)      // 있던 값 유지
        #expect(partial.lastDayKey == nil)       // 없던 필드는 기본값
        #expect(partial.promptedThresholds.isEmpty)
    }
}
