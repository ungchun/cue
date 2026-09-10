//
//  UserDefaultsAppSettingsRepository.swift
//  cue / Data
//

import Foundation

/// `AppSettingsRepository`의 UserDefaults 구현 — 단일 `AppSettings`를 한 키에 JSON으로
/// 저장한다(Memo 저장 패턴과 동일). 로컬 전용, iCloud 동기화 없음.
struct UserDefaultsAppSettingsRepository: AppSettingsRepository, @unchecked Sendable {
    private static let storageKey = "cue.appSettings.v1"
    private let defaults: UserDefaults
    /// 위젯(다른 프로세스)이 읽는 미러의 저장소. 테스트에서 실제 App Group을 건드리지 않도록 주입 가능.
    private let group: UserDefaults

    init(defaults: UserDefaults = .standard, group: UserDefaults = SharedAppGroup.defaults) {
        self.defaults = defaults
        self.group = group
    }

    func fetch() async -> AppSettings {
        let settings = fetchImmediately() ?? .default
        repairMirrorIfNeeded(settings)
        return settings
    }

    /// UserDefaults는 동기 저장소라 즉시 읽기가 가능하다 — 첫 프레임 전 시작 탭 결정에 쓴다.
    /// 저장값이 없거나 디코딩이 실패하면 nil(호출부가 기본값 처리).
    func fetchImmediately() -> AppSettings? {
        guard let data = defaults.data(forKey: Self.storageKey) else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }

    func save(_ settings: AppSettings) async {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.storageKey)
        }
        mirrorToAppGroup(settings)
    }

    // MARK: - App Group 미러

    /// 미러가 저장값과 어긋나 있으면 다시 맞춘다.
    ///
    /// **왜 필요한가** — 위젯은 `AppSettings`를 읽을 수 없어 LA 캘린더 표시를 미러만 보고 정한다.
    /// 그런데 미러는 `save()` 안에서만 쓰였다. 그래서 한 번 어긋나면(도메인별 쓰기 유실, 같은
    /// App Group에 쓰는 다른 프로세스의 클로버, 강등 정리와의 경합) 사용자가 그 토글을 **직접
    /// 다시 만질 때까지 영구히** 틀린 채 남는다 — "설정은 ON인데 잠금화면 캘린더가 안 뜬다".
    /// 재실행·재게시·프리미엄 재확인 중 어느 것도 이걸 고치지 못했다.
    ///
    /// 미러는 `AppSettings`에서 100% 파생되는 캐시라 방향이 항상 진실→미러 한쪽이다 —
    /// 저장값을 덮을 위험이 구조적으로 없다. 맞을 때는 쓰지 않는다(fetch는 화면 진입마다 불리고,
    /// 위젯 프로세스와 같은 도메인을 공유하므로 무의미한 쓰기를 던지지 않는다).
    private func repairMirrorIfNeeded(_ settings: AppSettings) {
        guard !mirrorMatches(settings) else { return }
        mirrorToAppGroup(settings)
    }

    /// 미러가 저장값과 일치하는지 — 재동기 여부를 가르는 판정(테스트로 고정).
    func mirrorMatches(_ settings: AppSettings) -> Bool {
        group.string(forKey: SharedAppGroup.Keys.memoTextSize) == settings.memoTextSize.rawValue
            && group.bool(forKey: SharedAppGroup.Keys.memoShowsCalendar) == settings.memoShowsCalendar
            && group.bool(forKey: SharedAppGroup.Keys.scheduleShowsCalendar) == settings.scheduleShowsCalendar
            && group.bool(forKey: SharedAppGroup.Keys.reminderShowsCalendar) == settings.reminderShowsCalendar
            // 순서는 의미 없다(집합) — 배열 비교로 오탐하지 않게 집합으로 견준다.
            && Set(group.stringArray(forKey: SharedAppGroup.Keys.hiddenCalendarIDs) ?? []) == settings.hiddenCalendarIDs
            && Set(group.stringArray(forKey: SharedAppGroup.Keys.hiddenReminderListIDs) ?? []) == settings.hiddenReminderListIDs
            // 표시 순서는 **배열 그대로** 견준다 — 순서 자체가 값이다.
            && (group.stringArray(forKey: SharedAppGroup.Keys.liveOrder) ?? [])
                == settings.resolvedLiveOrder.map(\.rawValue)
    }

    /// 위젯(다른 프로세스)이 읽을 LA 관련 설정을 App Group에 미러링한다 — 위젯은 Domain 타입을
    /// 모르므로 rawValue 문자열·불리언만 공유한다. (메모 LA 글자 크기, 캘린더 함께 표시)
    private func mirrorToAppGroup(_ settings: AppSettings) {
        group.set(settings.memoTextSize.rawValue, forKey: SharedAppGroup.Keys.memoTextSize)
        group.set(settings.memoShowsCalendar, forKey: SharedAppGroup.Keys.memoShowsCalendar)
        group.set(settings.scheduleShowsCalendar, forKey: SharedAppGroup.Keys.scheduleShowsCalendar)
        group.set(settings.reminderShowsCalendar, forKey: SharedAppGroup.Keys.reminderShowsCalendar)
        group.set(Array(settings.hiddenCalendarIDs), forKey: SharedAppGroup.Keys.hiddenCalendarIDs)
        group.set(Array(settings.hiddenReminderListIDs), forKey: SharedAppGroup.Keys.hiddenReminderListIDs)
        // 정제본을 실어 둔다 — 서비스는 미러를 그대로 신뢰하고 relevanceScore를 계산한다.
        group.set(settings.resolvedLiveOrder.map(\.rawValue), forKey: SharedAppGroup.Keys.liveOrder)
    }
}
