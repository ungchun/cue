//
//  ReconcilePremiumSettingsUseCaseTests.swift
//  cueTests
//

import Testing
@testable import cue

struct ReconcilePremiumSettingsUseCaseTests {

    private func makeUseCase(
        settings: AppSettings,
        memo: Memo = .default
    ) -> (ReconcilePremiumSettingsUseCase, InMemoryAppSettingsRepository, InMemoryMemoRepository) {
        let repository = InMemoryAppSettingsRepository(storage: settings)
        let memoRepository = InMemoryMemoRepository(memo: memo)
        let useCase = ReconcilePremiumSettingsUseCase(
            fetch: FetchAppSettingsUseCase(repository: repository),
            save: SaveAppSettingsUseCase(repository: repository),
            fetchMemo: FetchMemoUseCase(repository: memoRepository),
            saveMemo: SaveMemoUseCase(repository: memoRepository)
        )
        return (useCase, repository, memoRepository)
    }

    /// 비프리미엄인데 프리미엄 전용 설정이 켜져 있으면 전부 끄고 저장한다 —
    /// 구독 만료·게이트 이전 저장값 잔존으로 무료가 유료 기능을 계속 쓰는 걸 막는다.
    @Test func nonPremiumStripsPremiumOnlyFlags() async {
        var settings = AppSettings.default
        settings.liveAlwaysOn = true
        settings.memoShowsCalendar = true
        settings.scheduleShowsCalendar = true
        settings.reminderShowsCalendar = true
        let (useCase, repository, _) = makeUseCase(settings: settings)

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
        let (useCase, repository, _) = makeUseCase(settings: settings)

        let changed = await useCase(isPremium: true)

        #expect(changed == false)
        let saved = await repository.fetch()
        #expect(saved.liveAlwaysOn == true)
        #expect(saved.memoShowsCalendar == true)
    }

    /// 비프리미엄이라도 켜진 플래그가 없으면 저장하지 않는다(불필요한 write·미러 갱신 방지).
    @Test func nonPremiumWithNoFlagsIsNoOp() async {
        let (useCase, repository, _) = makeUseCase(settings: .default)

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
        let (useCase, repository, _) = makeUseCase(settings: settings)

        _ = await useCase(isPremium: false)

        let saved = await repository.fetch()
        #expect(saved.colorScheme == .dark)
        #expect(saved.startTabID == "focus")
    }

    /// 비프리미엄이면 메모 LA 커스텀 색(배경·글자)도 기본값으로 되돌린다 —
    /// 색은 AppSettings가 아닌 Memo에 살아 기존 정리에서 빠져 있던 유료 기능 잔존.
    @Test func nonPremiumResetsCustomMemoColors() async {
        let memo = Memo(text: "지금 이거", colorHex: "#FF3B30", textColorHex: "#00FF00")
        let (useCase, _, memoRepository) = makeUseCase(settings: .default, memo: memo)

        let changed = await useCase(isPremium: false)

        #expect(changed == true)
        let saved = await memoRepository.fetch()
        #expect(saved.colorHex == Memo.default.colorHex)
        #expect(saved.textColorHex == Memo.default.textColorHex)
    }

    /// 색을 되돌려도 메모 텍스트는 보존한다 — 텍스트는 무료 기능이자 사용자 데이터.
    @Test func memoColorResetPreservesText() async {
        let memo = Memo(text: "지금 이거", colorHex: "#FF3B30")
        let (useCase, _, memoRepository) = makeUseCase(settings: .default, memo: memo)

        _ = await useCase(isPremium: false)

        let saved = await memoRepository.fetch()
        #expect(saved.text == "지금 이거")
    }

    /// 프리미엄이면 커스텀 색을 건드리지 않는다.
    @Test func premiumKeepsCustomMemoColors() async {
        let memo = Memo(text: "지금 이거", colorHex: "#FF3B30", textColorHex: "#00FF00")
        let (useCase, _, memoRepository) = makeUseCase(settings: .default, memo: memo)

        let changed = await useCase(isPremium: true)

        #expect(changed == false)
        let saved = await memoRepository.fetch()
        #expect(saved.colorHex == "#FF3B30")
        #expect(saved.textColorHex == "#00FF00")
    }

    /// 비프리미엄이라도 색이 이미 기본값이면 메모를 저장하지 않는다(불필요 write 방지).
    @Test func nonPremiumWithDefaultColorsSkipsMemoSave() async {
        let memo = Memo(text: "지금 이거", colorHex: Memo.default.colorHex)
        let (useCase, _, memoRepository) = makeUseCase(settings: .default, memo: memo)

        let changed = await useCase(isPremium: false)

        #expect(changed == false)
        #expect(await memoRepository.saveCount == 0)
    }
}
