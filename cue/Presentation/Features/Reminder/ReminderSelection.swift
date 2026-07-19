//
//  ReminderSelection.swift
//  cue / Presentation
//

import Foundation

/// 미리알림 화면 본문에 무엇을 보여줄지 — 사용자 리스트 한 개 또는 시스템 필터.
/// 한 시점에 둘 중 하나만 활성이다 (둘 다 nil은 초기 적재 직전).
enum ReminderSelection: Equatable, Sendable {
    case list(String)                  // 사용자 리스트 ID
    case systemFilter(SystemFilter)    // 오늘 / 예정 / 전체

    /// 저장된 스코프 문자열("today"/"scheduled"/"all" 또는 사용자 리스트 id)을 선택으로 해석한다.
    /// 설정의 `tasksDefaultScopeID`·`liveAlwaysOnReminderScopeID`가 이 인코딩을 공유한다.
    /// 리스트 id가 가리키는 리스트가 삭제돼 없으면 `fallback`으로 떨어진다.
    static func resolve(
        scopeID: String,
        lists: [ReminderList],
        fallback: ReminderSelection
    ) -> ReminderSelection {
        switch scopeID {
        case "today": return .systemFilter(.today)
        case "scheduled": return .systemFilter(.scheduled)
        case "all": return .systemFilter(.all)
        default:
            return lists.contains(where: { $0.id == scopeID }) ? .list(scopeID) : fallback
        }
    }
}

/// 리스트 단위가 아닌 시스템 필터 — 칩 바의 첫 묶음.
enum SystemFilter: String, CaseIterable, Equatable, Sendable {
    /// 오늘 마감 + overdue 미완료.
    case today
    /// 마감일이 있는 모든 미완료.
    case scheduled
    /// 모든 미완료.
    case all

    /// 화면 상단 large title에 그대로 쓰는 라벨.
    var title: String {
        switch self {
        case .today: String(localized: "Today")
        case .scheduled: String(localized: "Scheduled")
        case .all: String(localized: "All")
        }
    }
}
