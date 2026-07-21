//
//  ReconcilePremiumSettingsUseCaseTests.swift
//  cueTests
//

import Testing
@testable import cue

struct ReconcilePremiumSettingsUseCaseTests {

    private func makeUseCase(
        settings: AppSettings
    ) -> (ReconcilePremiumSettingsUseCase, InMemoryAppSettingsRepository) {
        let repository = InMemoryAppSettingsRepository(storage: settings)
        let useCase = ReconcilePremiumSettingsUseCase(
            fetch: FetchAppSettingsUseCase(repository: repository),
            save: SaveAppSettingsUseCase(repository: repository)
        )
        return (useCase, repository)
    }

    /// 비프리미엄인데 프리미엄 전용 설정이 켜져 있으면 전부 끄고 저장한다 —
    /// 구독 만료·게이트 이전 저장값 잔존으로 무료가 유료 기능을 계속 쓰는 걸 막는다.
    @Test func nonPremiumStripsPremiumOnlyFlags() async {
        var settings = AppSettings.default
        settings.liveAlwaysOn = true
        settings.memoShowsCalendar = true
        settings.scheduleShowsCalendar = true
        settings.reminderShowsCalendar = true
        let (useCase, repository) = makeUseCase(settings: settings)

        let changed = await useCase(isPremium: false)

        #expect(changed == true)
        let saved = await repository.fetch()
        #expect(saved.liveAlwaysOn == false)
        #expect(saved.memoShowsCalendar == false)
        #expect(saved.scheduleShowsCalendar == false)
        #expect(saved.reminderShowsCalendar == false)
    }

    /// 프리미엄이면 아무것도 바꾸지 않는다.
    @Test func premiumKeepsFlagsUntouched() async {
        var settings = AppSettings.default
        settings.liveAlwaysOn = true
        settings.memoShowsCalendar = true
        let (useCase, repository) = makeUseCase(settings: settings)

        let changed = await useCase(isPremium: true)

        #expect(changed == false)
        let saved = await repository.fetch()
        #expect(saved.liveAlwaysOn == true)
        #expect(saved.memoShowsCalendar == true)
    }

    /// 비프리미엄이라도 켜진 플래그가 없으면 저장하지 않는다(불필요한 write·미러 갱신 방지).
    @Test func nonPremiumWithNoFlagsIsNoOp() async {
        let (useCase, repository) = makeUseCase(settings: .default)

        let changed = await useCase(isPremium: false)

        #expect(changed == false)
        #expect(await repository.saveCount == 0)
    }

    /// 프리미엄 전용이 아닌 설정(화면 모드·시작 탭 등)은 건드리지 않는다.
    @Test func stripPreservesNonPremiumSettings() async {
        var settings = AppSettings.default
        settings.colorScheme = .dark
        settings.startTabID = "focus"
        settings.liveAlwaysOn = true
        let (useCase, repository) = makeUseCase(settings: settings)

        _ = await useCase(isPremium: false)

        let saved = await repository.fetch()
        #expect(saved.colorScheme == .dark)
        #expect(saved.startTabID == "focus")
    }
}
