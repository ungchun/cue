//
//  ReconcilePremiumSettingsUseCase.swift
//  cue / Domain
//

/// 앱 시작 시 엔타이틀먼트와 프리미엄 전용 설정을 맞춘다 — 강등(구독 만료·환불) 사용자 방어.
///
/// 프리미엄 게이트는 "설정을 켜는 순간"에만 있어, 프리미엄 기간(또는 게이트 이전 빌드)에 켜둔
/// `liveAlwaysOn`·`showsCalendar` 저장값이 강등 후에도 남아 무료로 유료 기능을 계속 부여한다.
/// 이 use case가 시작 시 비프리미엄이면 해당 플래그를 꺼서 저장한다 — 저장 리포지토리가
/// App Group 미러까지 갱신하므로 위젯(LA 캘린더)도 함께 닫힌다.
struct ReconcilePremiumSettingsUseCase: Sendable {
    private let fetch: FetchAppSettingsUseCase
    private let save: SaveAppSettingsUseCase

    init(fetch: FetchAppSettingsUseCase, save: SaveAppSettingsUseCase) {
        self.fetch = fetch
        self.save = save
    }

    /// 비프리미엄이면 프리미엄 전용 플래그를 정리하고, 실제로 바뀐 경우에만 저장 후 true.
    /// 프리미엄이거나 켜진 플래그가 없으면 아무것도 하지 않는다(불필요한 write·미러 갱신 방지).
    @discardableResult
    func callAsFunction(isPremium: Bool) async -> Bool {
        guard !isPremium else { return false }
        var settings = await fetch()
        let hadPremiumFlags = settings.liveAlwaysOn
            || settings.memoShowsCalendar
            || settings.scheduleShowsCalendar
            || settings.reminderShowsCalendar
        guard hadPremiumFlags else { return false }
        settings.liveAlwaysOn = false
        settings.memoShowsCalendar = false
        settings.scheduleShowsCalendar = false
        settings.reminderShowsCalendar = false
        await save(settings)
        return true
    }
}
