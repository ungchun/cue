//
//  ReminderSortPreference.swift
//  cue / Domain
//

import Foundation

/// 미리알림 섹션(오늘·개별 리스트)의 정렬 기준. Apple 미리 알림 "다음으로 정렬"과 대응.
/// `manual`은 사용자가 드래그로 직접 배열한 순서 — 방향 개념이 없다.
/// (전체·예정 섹션은 이 설정을 쓰지 않는다 — 별도 고정 정렬.)
enum ReminderSortField: String, Codable, Sendable {
    case manual
    case dueDate
    case creationDate
    case title
}

/// 정렬 방향. 의미는 field별로 다르다 —
/// dueDate: asc=이른 항목 순/desc=늦은 항목 순, creationDate: asc=오래된 순/desc=최신 순,
/// title: asc=가나다 순/desc=역순. `manual`이면 무시된다.
enum ReminderSortDirection: String, Codable, Sendable {
    case ascending
    case descending
}

/// 한 섹션의 정렬 기준 + 방향.
struct ReminderSortPreference: Codable, Equatable, Sendable {
    var field: ReminderSortField
    var direction: ReminderSortDirection

    /// 기본 정렬 — Apple 미리 알림과 동일하게 `manual`. 수동 순서가 비어 있으면
    /// 생성일 오래된 순을 시드로 보여준다(ViewModel 정렬 로직).
    static let `default` = ReminderSortPreference(field: .manual, direction: .ascending)
}

/// 섹션 단위로 저장되는 정렬 상태 — 기준/방향 + 수동 순서(reminder ID 배열).
/// 드래그로 재배열하면 `preference.field = .manual`로 바뀌고 `manualOrder`가 갱신된다.
struct ReminderSortSettings: Codable, Equatable, Sendable {
    var preference: ReminderSortPreference
    /// 수동 정렬 순서(reminder ID). 비어 있으면 생성일 오래된 순을 시드로 쓴다.
    /// 목록에 없는(새로 추가된) 항목은 맨 뒤에 붙는다.
    var manualOrder: [String]

    static let `default` = ReminderSortSettings(preference: .default, manualOrder: [])
}
