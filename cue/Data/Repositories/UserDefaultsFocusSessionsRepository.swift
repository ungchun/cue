//
//  UserDefaultsFocusSessionsRepository.swift
//  cue / Data
//

import Foundation

/// `FocusSessionsRepository`의 영속 구현 — `UserDefaults`에 JSON으로 직렬화 저장한다.
///
/// 세션 프리셋은 양이 적어(보통 < 20건) 한 번에 통째로 read/write해도 충분하다. SwiftData
/// 모델·마이그레이션 부담을 피하고 가벼운 영속화로 끝낸다. `UserDefaults`는 Apple 문서상
/// thread-safe이지만 Sendable 어노테이션이 없어 `@unchecked Sendable`로 명시.
struct UserDefaultsFocusSessionsRepository: FocusSessionsRepository, @unchecked Sendable {
    /// 저장 키 — 스키마 변경 시 `v1` 부분만 올려서 자동 마이그레이션(빈 배열) 효과를 얻는다.
    private static let storageKey = "cue.focus.sessions.v1"
    /// 마지막으로 선택된 세션 id 저장 키. sessions 스키마와 의도적으로 분리 —
    /// 한쪽 스키마를 올려도 다른 쪽은 그대로 살린다.
    private static let selectedIDKey = "cue.focus.selectedSession.v1"
    /// 진행 중 세션 스냅샷 저장 키. 또 별도 키 — 상태 변할 때마다 덮어쓰고, 종료 시 지운다.
    private static let activeSessionKey = "cue.focus.activeSession.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func fetchAll() async -> [FocusSession] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let sessions = try? JSONDecoder().decode([FocusSession].self, from: data) else {
            return []
        }
        return sessions
    }

    func save(_ sessions: [FocusSession]) async {
        // 인코딩 실패는 거의 일어나지 않지만, 일어나면 조용히 무시 — 다음 save 호출에서 다시 시도.
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    func fetchSelectedSessionID() async -> UUID? {
        // UUID는 짧은 단일 문자열이므로 JSON 인코딩 없이 string으로 저장 — 한 키 한 값 단순.
        guard let raw = defaults.string(forKey: Self.selectedIDKey) else { return nil }
        return UUID(uuidString: raw)
    }

    func saveSelectedSessionID(_ id: UUID?) async {
        // nil이면 키 자체를 지운다 — 다음 fetch에서 자연스레 nil로 떨어진다.
        if let id {
            defaults.set(id.uuidString, forKey: Self.selectedIDKey)
        } else {
            defaults.removeObject(forKey: Self.selectedIDKey)
        }
    }

    func fetchActiveSession() async -> ActiveFocusSessionSnapshot? {
        guard let data = defaults.data(forKey: Self.activeSessionKey),
              let snapshot = try? JSONDecoder().decode(ActiveFocusSessionSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }

    func saveActiveSession(_ snapshot: ActiveFocusSessionSnapshot?) async {
        // nil이면 키 자체를 지운다 — 세션 종료/완료 시 호출돼 "복원할 세션 없음" 상태로.
        guard let snapshot else {
            defaults.removeObject(forKey: Self.activeSessionKey)
            return
        }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.activeSessionKey)
    }
}
