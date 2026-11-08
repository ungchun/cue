//
//  FetchScheduleDisplayModeUseCaseTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 일정 탭 표시 모드는 첫 프레임 전에 알아야 해서 동기 경로다 — 그 계약과 기본값을 고정한다.
struct FetchScheduleDisplayModeUseCaseTests {

    /// 저장값이 없으면 월 캘린더.
    @Test func returnsMonthWhenNothingSaved() {
        let sut = FetchScheduleDisplayModeUseCase(repository: InMemoryScheduleDisplayModeRepository())

        #expect(sut() == .month)
    }

    /// 저장된 모드를 await 없이 그 자리에서 돌려준다.
    @Test func returnsSavedModeSynchronously() {
        let sut = FetchScheduleDisplayModeUseCase(
            repository: InMemoryScheduleDisplayModeRepository(mode: .timeline)
        )

        #expect(sut() == .timeline)
    }

    /// Save → Fetch가 같은 저장소를 통해 이어진다.
    @Test func saveUseCaseFeedsFetchUseCase() {
        let repository = InMemoryScheduleDisplayModeRepository()

        SaveScheduleDisplayModeUseCase(repository: repository)(.timeline)

        #expect(FetchScheduleDisplayModeUseCase(repository: repository)() == .timeline)
    }
}
