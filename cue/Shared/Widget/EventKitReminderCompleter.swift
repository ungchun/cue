//
//  EventKitReminderCompleter.swift
//  cue / Shared
//

import EventKit

/// EventKit 미리알림 완료 처리 — LA 인텐트(앱 프로세스)와 홈 위젯 인텐트(익스텐션
/// 프로세스)가 같은 로직을 공유한다. 익스텐션은 컨테이너 앱의 미리알림 권한을 그대로
/// 물려받으므로 어느 프로세스에서 불러도 동작이 같다.
///
/// EventKit 경계 글루라 RED 면제 — 분기랄 것이 권한·조회 실패뿐이다.
enum EventKitReminderCompleter {

    /// 해당 미리알림을 완료 처리. 성공하면 `true`.
    static func complete(id: String) -> Bool {
        let store = EKEventStore()
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess,
              let reminder = store.calendarItem(withIdentifier: id) as? EKReminder
        else { return false }
        reminder.isCompleted = true
        return (try? store.save(reminder, commit: true)) != nil
    }
}
