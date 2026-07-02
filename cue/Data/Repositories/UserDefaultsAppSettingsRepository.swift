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
        guard let data = defaults.data(forKey: Self.storageKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return .default }
        return settings
    }

    func save(_ settings: AppSettings) async {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.storageKey)
        }
        mirrorToAppGroup(settings)
    }

    /// 위젯(다른 프로세스)이 읽을 LA 관련 설정을 App Group에 미러링한다 — 위젯은 Domain 타입을
    /// 모르므로 rawValue 문자열만 공유한다. (메모 LA 글자 크기)
    private func mirrorToAppGroup(_ settings: AppSettings) {
        let group = SharedAppGroup.defaults
        group.set(settings.memoTextSize.rawValue, forKey: SharedAppGroup.Keys.memoTextSize)
    }
}
