//
//  CompleteReminderIntent.swift
//  cue / Shared
//

@preconcurrency import ActivityKit
import AppIntents
import EventKit
import Foundation
import WidgetKit

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
    /// 단축어 갤러리에 노출할 이유가 없다 — LA 버튼 전용(reminderID를 손으로 채워야 해 무의미).
    static let isDiscoverable = false

    @Parameter(title: "reminderID") var reminderID: String

    init() {}
    init(reminderID: String) { self.reminderID = reminderID }

    func perform() async throws -> some IntentResult {
        // EventKit 완료가 성공한 경우에만 LA에서 제거 — 실패 시 화면-시스템 불일치 방지.
        guard completeReminder(id: reminderID) else { return .result() }
        // 본앱 스키마(reminderCompleted(source:))와 이름·파라미터를 맞춘다 — 익스텐션 프로세스에선 no-op.
        LiveActivityAnalyticsBridge.log?("reminder_completed", ["source": "live_activity"])
        await removeFromLiveActivity(id: reminderID)
        // 홈 화면 캘린더 위젯도 함께 갱신 — 위젯은 완료된 할 일을 지우는 게 아니라 **체크된
        // 모습으로** 그리므로(`WidgetCalendarDataSource.showsReminder`) 여기서 갱신하지 않으면
        // LA에서는 사라진 항목이 위젯에는 미완료로 남는다. 잠금화면에 LA와 위젯이 함께 있을 수
        // 있어 그 불일치가 눈앞에 보이고, LA 체크는 앱을 열 이유가 없는 동작이라
        // `scenePhase` 이탈 갱신(cueApp)이 구제해주지 않는다.
        //
        // 캘린더 위젯만 집는다 — `reloadAllTimelines()`는 LA까지 재생성해 갱신 예산을 태우고,
        // 예산이 마르면 자정·정시 타임라인이 미뤄져 오히려 더 낡는다.
        for kind in CalendarWidgetKind.all {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
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
    ///
    /// `activities.first`가 아니라 `liveActivity`를 쓴다 — 목록엔 시스템이 종료한
    /// (`.ended`) · 사용자가 치운(`.dismissed`) 인스턴스도 남아 있고, 거기 보낸 update는
    /// 예외 없이 무시된다. 오래된 LA에서 체크가 안 먹던 원인이 이것이다.
    private func removeFromLiveActivity(id: String) async {
        guard let activity = Activity<ReminderLiveActivityAttributes>.liveActivity else { return }
        let next = activity.content.state.removingItem(id: id)
        await activity.update(ActivityContent(state: next, staleDate: nil))
    }
}
