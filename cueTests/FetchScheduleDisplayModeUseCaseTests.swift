//
//  FetchScheduleDisplayModeUseCaseTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 일정 탭 표시 모드는 첫 프레임 전에 알아야 해서 동기 경로다 — 그 계약과 기본값을 고정한다.
struct FetchScheduleDisplayModeUseCaseTests {

    /// 저장값이 없으면 타임라인.
    @Test func returnsTimelineWhenNothingSaved() {
        let sut = FetchScheduleDisplayModeUseCase(repository: InMemoryScheduleDisplayModeRepository())

        #expect(sut() == .timeline)
    }

    /// 저장된 모드를 await 없이 그 자리에서 돌려준다.
    @Test func returnsSavedModeSynchronously() {
        let sut = FetchScheduleDisplayModeUseCase(
            repository: InMemoryScheduleDisplayModeRepository(mode: .month)
        )

        #expect(sut() == .month)
    }

    /// Save → Fetch가 같은 저장소를 통해 이어진다.
    @Test func saveUseCaseFeedsFetchUseCase() {
        let repository = InMemoryScheduleDisplayModeRepository()

        SaveScheduleDisplayModeUseCase(repository: repository)(.month)

        #expect(FetchScheduleDisplayModeUseCase(repository: repository)() == .month)
    }
}
