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
    private let fetchMemo: FetchMemoUseCase
    private let saveMemo: SaveMemoUseCase

    init(
        fetch: FetchAppSettingsUseCase,
        save: SaveAppSettingsUseCase,
        fetchMemo: FetchMemoUseCase,
        saveMemo: SaveMemoUseCase
    ) {
        self.fetch = fetch
        self.save = save
        self.fetchMemo = fetchMemo
        self.saveMemo = saveMemo
    }

    /// 확정 판정에 따라 프리미엄 전용 설정을 정리(무료)하거나 복구(유료)하고,
    /// 실제로 바뀐 경우에만 저장 후 true. 바꿀 게 없으면 아무것도 하지 않는다.
    ///
    /// **호출 전제**: `isPremium`은 **확정 판정**이어야 한다 — 조회 실패(신뢰 불가)를
    /// 무료로 넘기면 유료 사용자의 설정을 파괴한다. 호출부는 `PremiumStore.confirmedIsPremium`이
    /// nil이 아닐 때만 부른다.
    /// settings·memo를 **각 1회씩만** fetch/save 한다 — fold/restore가 설정을 여러 번 통으로
    /// 다시 쓰면 SettingsViewModel 저장과의 경합 창이 그만큼 넓어진다(리뷰 지적).
    @discardableResult
    func callAsFunction(isPremium: Bool) async -> Bool {
        var settings = await fetch()
        var memo = await fetchMemo()
        let (settingsChanged, memoChanged) = isPremium
            ? Self.restore(into: &settings, memo: &memo)
            : Self.fold(into: &settings, memo: &memo)
        if settingsChanged { await save(settings) }
        if memoChanged { await saveMemo(memo) }
        return settingsChanged || memoChanged
    }

    // MARK: - 강등(확정 무료) — 끄되, "원래 켜져 있었음"을 접어둔다

    /// 플래그·메모 색을 접어 끈다. 이미 꺼진 상태의 재실행은 기록을 덮지 않는다
    /// (기록은 ||·nil-coalescing으로만 추가 — 두 번째 실행이 지우면 복구 무산).
    private static func fold(into settings: inout AppSettings, memo: inout Memo) -> (settings: Bool, memo: Bool) {
        var settingsChanged = false
        let hadPremiumFlags = settings.liveAlwaysOn
            || settings.memoShowsCalendar
            || settings.scheduleShowsCalendar
            || settings.reminderShowsCalendar
        if hadPremiumFlags {
            settings.demotedLiveAlwaysOn = settings.demotedLiveAlwaysOn || settings.liveAlwaysOn
            settings.demotedMemoShowsCalendar = settings.demotedMemoShowsCalendar || settings.memoShowsCalendar
            settings.demotedScheduleShowsCalendar = settings.demotedScheduleShowsCalendar || settings.scheduleShowsCalendar
            settings.demotedReminderShowsCalendar = settings.demotedReminderShowsCalendar || settings.reminderShowsCalendar
            settings.liveAlwaysOn = false
            settings.memoShowsCalendar = false
            settings.scheduleShowsCalendar = false
            settings.reminderShowsCalendar = false
            settingsChanged = true
        }
        // 메모 색 — 색은 AppSettings가 아닌 Memo에 살아 별도 정리. 텍스트는 사용자 데이터라 보존.
        var memoChanged = false
        let fallback = Memo.default
        if memo.colorHex != fallback.colorHex || memo.textColorHex != fallback.textColorHex {
            settings.demotedMemoColorHex = settings.demotedMemoColorHex ?? memo.colorHex
            settings.demotedMemoTextColorHex = settings.demotedMemoTextColorHex ?? memo.textColorHex
            memo.colorHex = fallback.colorHex
            memo.textColorHex = fallback.textColorHex
            settingsChanged = true
            memoChanged = true
        }
        return (settingsChanged, memoChanged)
    }

    // MARK: - 재구독(확정 유료) — 접어둔 설정 자동 복구

    /// 접어둔 플래그·색을 되켜고 기록을 비운다 — 사용자가 수동으로 다시 켤 필요가 없게.
    private static func restore(into settings: inout AppSettings, memo: inout Memo) -> (settings: Bool, memo: Bool) {
        let hadColorRecord = settings.demotedMemoColorHex != nil || settings.demotedMemoTextColorHex != nil
        let hadRecord = settings.demotedLiveAlwaysOn
            || settings.demotedMemoShowsCalendar
            || settings.demotedScheduleShowsCalendar
            || settings.demotedReminderShowsCalendar
            || hadColorRecord
        guard hadRecord else { return (false, false) }
        settings.liveAlwaysOn = settings.liveAlwaysOn || settings.demotedLiveAlwaysOn
        settings.memoShowsCalendar = settings.memoShowsCalendar || settings.demotedMemoShowsCalendar
        settings.scheduleShowsCalendar = settings.scheduleShowsCalendar || settings.demotedScheduleShowsCalendar
        settings.reminderShowsCalendar = settings.reminderShowsCalendar || settings.demotedReminderShowsCalendar
        memo.colorHex = settings.demotedMemoColorHex ?? memo.colorHex
        memo.textColorHex = settings.demotedMemoTextColorHex ?? memo.textColorHex
        settings.demotedLiveAlwaysOn = false
        settings.demotedMemoShowsCalendar = false
        settings.demotedScheduleShowsCalendar = false
        settings.demotedReminderShowsCalendar = false
        settings.demotedMemoColorHex = nil
        settings.demotedMemoTextColorHex = nil
        return (true, hadColorRecord)
    }
}
