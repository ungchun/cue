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
    @discardableResult
    func callAsFunction(isPremium: Bool) async -> Bool {
        if isPremium {
            let flagsChanged = await restoreDemotedFlags()
            let memoChanged = await restoreDemotedMemoColors()
            return flagsChanged || memoChanged
        }
        let flagsChanged = await foldPremiumFlags()
        let memoChanged = await foldMemoColors()
        return flagsChanged || memoChanged
    }

    // MARK: - 강등(확정 무료) — 끄되, "원래 켜져 있었음"을 접어둔다

    /// 항상표시·캘린더 함께 보기 플래그 정리 — 켜진 게 있을 때만 저장하고, 끈 플래그를 기록한다.
    /// 이미 꺼진 상태의 재실행은 기록을 덮지 않는다(두 번째 실행이 기록을 지우면 복구 무산).
    private func foldPremiumFlags() async -> Bool {
        var settings = await fetch()
        let hadPremiumFlags = settings.liveAlwaysOn
            || settings.memoShowsCalendar
            || settings.scheduleShowsCalendar
            || settings.reminderShowsCalendar
        guard hadPremiumFlags else { return false }
        // 켜져 있던 것만 기록에 **추가**한다(|| — 기존 기록 보존).
        settings.demotedLiveAlwaysOn = settings.demotedLiveAlwaysOn || settings.liveAlwaysOn
        settings.demotedMemoShowsCalendar = settings.demotedMemoShowsCalendar || settings.memoShowsCalendar
        settings.demotedScheduleShowsCalendar = settings.demotedScheduleShowsCalendar || settings.scheduleShowsCalendar
        settings.demotedReminderShowsCalendar = settings.demotedReminderShowsCalendar || settings.reminderShowsCalendar
        settings.liveAlwaysOn = false
        settings.memoShowsCalendar = false
        settings.scheduleShowsCalendar = false
        settings.reminderShowsCalendar = false
        await save(settings)
        return true
    }

    /// 메모 LA 커스텀 색(배경·글자) 정리 — 색은 AppSettings가 아닌 Memo에 살아 별도로 되돌린다.
    /// 원래 값은 설정에 접어두고, 텍스트는 무료 기능이자 사용자 데이터라 보존.
    /// 이미 기본색이면 저장하지 않는다.
    private func foldMemoColors() async -> Bool {
        var memo = await fetchMemo()
        let fallback = Memo.default
        guard memo.colorHex != fallback.colorHex || memo.textColorHex != fallback.textColorHex else {
            return false
        }
        var settings = await fetch()
        // 이미 접어둔 기록이 있으면 보존 — 재실행이 "기본색"으로 기록을 덮으면 복구 무산.
        settings.demotedMemoColorHex = settings.demotedMemoColorHex ?? memo.colorHex
        settings.demotedMemoTextColorHex = settings.demotedMemoTextColorHex ?? memo.textColorHex
        await save(settings)
        memo.colorHex = fallback.colorHex
        memo.textColorHex = fallback.textColorHex
        await saveMemo(memo)
        return true
    }

    // MARK: - 재구독(확정 유료) — 접어둔 설정 자동 복구

    /// 접어둔 플래그를 되켜고 기록을 비운다 — 사용자가 수동으로 다시 켤 필요가 없게.
    private func restoreDemotedFlags() async -> Bool {
        var settings = await fetch()
        let hadRecord = settings.demotedLiveAlwaysOn
            || settings.demotedMemoShowsCalendar
            || settings.demotedScheduleShowsCalendar
            || settings.demotedReminderShowsCalendar
        guard hadRecord else { return false }
        settings.liveAlwaysOn = settings.liveAlwaysOn || settings.demotedLiveAlwaysOn
        settings.memoShowsCalendar = settings.memoShowsCalendar || settings.demotedMemoShowsCalendar
        settings.scheduleShowsCalendar = settings.scheduleShowsCalendar || settings.demotedScheduleShowsCalendar
        settings.reminderShowsCalendar = settings.reminderShowsCalendar || settings.demotedReminderShowsCalendar
        settings.demotedLiveAlwaysOn = false
        settings.demotedMemoShowsCalendar = false
        settings.demotedScheduleShowsCalendar = false
        settings.demotedReminderShowsCalendar = false
        await save(settings)
        return true
    }

    /// 접어둔 메모 색을 되돌리고 기록을 비운다 — 그 사이 편집된 텍스트는 보존.
    private func restoreDemotedMemoColors() async -> Bool {
        var settings = await fetch()
        guard settings.demotedMemoColorHex != nil || settings.demotedMemoTextColorHex != nil else {
            return false
        }
        var memo = await fetchMemo()
        memo.colorHex = settings.demotedMemoColorHex ?? memo.colorHex
        memo.textColorHex = settings.demotedMemoTextColorHex ?? memo.textColorHex
        await saveMemo(memo)
        settings.demotedMemoColorHex = nil
        settings.demotedMemoTextColorHex = nil
        await save(settings)
        return true
    }
}
