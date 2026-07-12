//
//  CompleteReminderIntent.swift
//  cue / Shared
//

@preconcurrency import ActivityKit
import AppIntents
import EventKit
import Foundation

// MARK: - 타깃 멤버십
//
// 위젯이 `Button(intent:)`로 참조하므로 **앱 + 익스텐션 양쪽**에 컴파일된다(pbxproj exception).
// 따라서 앱 전용 타입(`RemindersRepository` 등)은 참조하지 않고, 시스템 프레임워크(EventKit·
// ActivityKit)만으로 자급자족한다.
//
// `LiveActivityIntent`라 perform()은 **메인 앱 프로세스**에서 실행된다(앱이 종료돼 있어도 시스템이
// 백그라운드로 깨움) — 그래서 앱에 이미 부여된 미리알림 권한을 그대로 쓸 수 있고, 익스텐션에 별도
// 권한을 요구하지 않는다.

/// LA 체크박스 탭 — 해당 미리알림을 완료 처리하고 LA 화면에서 숨긴다.
struct CompleteReminderIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Complete Reminder"

    @Parameter(title: "reminderID") var reminderID: String

    init() {}
    init(reminderID: String) { self.reminderID = reminderID }

    func perform() async throws -> some IntentResult {
        // EventKit 완료가 성공한 경우에만 LA에서 제거 — 실패 시 화면-시스템 불일치 방지.
        guard completeReminder(id: reminderID) else { return .result() }
        await removeFromLiveActivity(id: reminderID)
        return .result()
    }

    /// EventKit에서 해당 미리알림을 완료 처리. 성공하면 `true`.
    private func completeReminder(id: String) -> Bool {
        let store = EKEventStore()
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess,
              let reminder = store.calendarItem(withIdentifier: id) as? EKReminder
        else { return false }
        reminder.isCompleted = true
        return (try? store.save(reminder, commit: true)) != nil
    }

    /// 완료된 항목을 살아있는 미리알림 LA에서 제거(표시 카운트도 함께 감소).
    private func removeFromLiveActivity(id: String) async {
        guard let activity = Activity<ReminderLiveActivityAttributes>.activities.first else { return }
        let next = activity.content.state.removingItem(id: id)
        await activity.update(ActivityContent(state: next, staleDate: nil))
    }
}
