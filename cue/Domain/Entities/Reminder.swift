//
//  Reminder.swift
//  cue / Domain
//

import Foundation

/// 미리 알림 항목 하나 — iOS "미리 알림" 앱의 한 항목에 대응하는 도메인 엔티티.
///
/// `includesTime` — EventKit의 `dueDateComponents`에 시·분이 들어있는지(=시각 지정),
/// 없으면 종일(date-only). 도메인이 직접 이 구분을 들고 있어야 수정 시 시트 토글을
/// 정확히 복원할 수 있다. 기본값 false는 마감일이 없는 항목/단순 생성을 위한 편의.
struct Reminder: Identifiable, Equatable, Sendable, Codable {
    let id: String
    var title: String
    var isCompleted: Bool
    var notes: String?
    var dueDate: Date?
    var includesTime: Bool = false
    /// 반복 주기. nil이면 일회성 항목. EventKit `recurrenceRules`의 첫 규칙만 매핑한다.
    var recurrence: RecurrenceRule? = nil
    /// 생성 시각(EventKit `creationDate`). 시스템 필터(전체·예정)의 "추가한 순서" 정렬 기준.
    /// nil이면 정렬에서 맨 뒤로 보낸다(미리 알림 앱과 동일하게 가장 나중에 추가된 것 취급).
    var creationDate: Date? = nil
    /// 우선순위(EventKit `priority`를 4단계로 접은 값).
    var priority: ReminderPriority = .none
    /// 위치 기반 알림(도착·출발). nil이면 없음.
    var locationAlarm: ReminderLocationAlarm? = nil
    /// 속한 리스트 — 전체 탭 섹션 간 드래그(리스트 이동)로 바뀔 수 있어 가변.
    var listID: String
}

extension Reminder {
    // 커스텀 디코딩은 extension에 둬서 멤버와이즈 init을 살린다. 새 필드(priority·locationAlarm)는
    // decodeIfPresent — 필드 추가 전에 저장된 스냅샷(JSON)도 그대로 읽혀, 업데이트 직후 첫
    // 페인트가 캐시 디코딩 실패로 스피너에 떨어지지 않는다(RecurrenceRule과 같은 방식).
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            title: try container.decode(String.self, forKey: .title),
            isCompleted: try container.decode(Bool.self, forKey: .isCompleted),
            notes: try container.decodeIfPresent(String.self, forKey: .notes),
            dueDate: try container.decodeIfPresent(Date.self, forKey: .dueDate),
            includesTime: try container.decode(Bool.self, forKey: .includesTime),
            recurrence: try container.decodeIfPresent(RecurrenceRule.self, forKey: .recurrence),
            creationDate: try container.decodeIfPresent(Date.self, forKey: .creationDate),
            priority: try container.decodeIfPresent(ReminderPriority.self, forKey: .priority)
                ?? ReminderPriority.none,
            locationAlarm: try container.decodeIfPresent(ReminderLocationAlarm.self, forKey: .locationAlarm),
            listID: try container.decode(String.self, forKey: .listID)
        )
    }
}
