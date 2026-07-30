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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func fetch() async -> AppSettings {
        fetchImmediately() ?? .default
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

    /// 위젯(다른 프로세스)이 읽을 LA 관련 설정을 App Group에 미러링한다 — 위젯은 Domain 타입을
    /// 모르므로 rawValue 문자열·불리언만 공유한다. (메모 LA 글자 크기, 캘린더 함께 표시)
    private func mirrorToAppGroup(_ settings: AppSettings) {
        let group = SharedAppGroup.defaults
        group.set(settings.memoTextSize.rawValue, forKey: SharedAppGroup.Keys.memoTextSize)
        group.set(settings.memoShowsCalendar, forKey: SharedAppGroup.Keys.memoShowsCalendar)
        group.set(settings.scheduleShowsCalendar, forKey: SharedAppGroup.Keys.scheduleShowsCalendar)
        group.set(settings.reminderShowsCalendar, forKey: SharedAppGroup.Keys.reminderShowsCalendar)
        group.set(Array(settings.hiddenCalendarIDs), forKey: SharedAppGroup.Keys.hiddenCalendarIDs)
    }
}
