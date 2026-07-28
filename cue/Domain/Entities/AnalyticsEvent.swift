//
//  AnalyticsEvent.swift
//  cue / Domain
//

/// 앱이 기록하는 분석 이벤트 — 이름·파라미터 매핑을 한곳에 모은 순수 모델.
///
/// 케이스를 추가하면 `name`/`parameters`가 곧 GA4 이벤트 스키마다. 이름은 snake_case
/// (GA4 관례), 파라미터 값은 전부 문자열로 통일해 대시보드에서 일관되게 읽히게 한다.
/// Firebase 전송은 Data 계층(`FirebaseAnalyticsService`)이 담당 — Domain은 SDK를 모른다.
/// `source`는 같은 행동이 앱 내부("app")와 잠금화면 Live Activity("live_activity") 양쪽에서
/// 일어날 수 있는 이벤트에만 붙인다 — 채널별 사용량을 분리 집계하기 위해서다.
enum AnalyticsEvent: Equatable, Sendable {
    // 화면
    case tabViewed(tab: String)

    // 라이브 액티비티
    case liveToggled(kind: String, on: Bool)
    case liveDenied(kind: String)
    case liveCalendarShifted(kind: String, direction: String)

    // 메모
    case memoSaved
    case memoCleared

    // 일정
    case eventCreated
    case eventUpdated
    case eventDeleted

    // 리마인더
    case reminderCreated
    case reminderCompleted(source: String)
    case reminderUncompleted
    case reminderUpdated
    case reminderDeleted
    case reminderReordered
    case reminderMovedToList
    case reminderScopeSelected(scope: String)
    case reminderSortChanged(key: String, order: String)
    case reminderShowCompletedToggled(on: Bool)
    case reminderListCreated
    case reminderListUpdated
    case reminderListDeleted

    // 집중
    case focusStarted
    case focusPaused(source: String)
    case focusResumed(source: String)
    case focusSkipped
    case focusEnded(source: String)
    case focusCompleted
    case focusPermissionDenied
    case focusPhaseAdvanced(source: String)
    case focusSessionCreated
    case focusSessionUpdated
    case focusSessionDeleted
    case focusSessionSelected
    case focusSessionLimitReached

    // 프리미엄
    case paywallShown(source: String)
    case paywallDismissed
    case planSelected(plan: String)
    case purchaseAttempted(plan: String, trial: Bool)
    case purchaseResult(plan: String, outcome: String, trial: Bool)
    case restoreTapped
    case restoreResult(outcome: String)
    case entitlementChanged(premium: Bool)
    case premiumGateHit(feature: String)
    case termsTapped
    case privacyTapped
    case productsLoadFailed

    // 설정
    case alwaysOnToggled(on: Bool)
    case showCalendarToggled(kind: String, on: Bool)
    case textSizeChanged(size: String)
    case displayModeChanged(mode: String)
    case startTabChanged(tab: String)
    case liveItemToggled(kind: String, on: Bool)
    case liveScopeChanged(scope: String)
    case liveColorChanged(kind: String)
    case tasksDefaultViewChanged(view: String)
    case focusEndSoundToggled(on: Bool)
    case calendarVisibilityToggled(kind: String, on: Bool)
    case calendarShowAllTapped(kind: String)
    case live24hGuideOpened

    // 앱
    case forcedUpdatePrompted
    case forcedUpdateTapped
    /// 리뷰 요청 — `source`로 자동("live": 라이브 게시 후 문턱 도달)과 수동("settings": 사용자 탭)을 가른다.
    /// 두 경로는 동작이 다르다: 자동은 시스템 프롬프트(안 뜰 수 있음), 수동은 App Store 리뷰 작성 페이지.
    case reviewRequested(source: String)
    case feedbackTapped
    case onboardingReplayTapped
    case externalAppOpened(app: String)
    case permissionSettingsOpened(kind: String)

    /// GA4 이벤트 이름.
    var name: String {
        switch self {
        case .tabViewed: "tab_viewed"
        case .liveToggled: "live_toggled"
        case .liveDenied: "live_denied"
        case .liveCalendarShifted: "live_calendar_shifted"
        case .memoSaved: "memo_saved"
        case .memoCleared: "memo_cleared"
        case .eventCreated: "event_created"
        case .eventUpdated: "event_updated"
        case .eventDeleted: "event_deleted"
        case .reminderCreated: "reminder_created"
        case .reminderCompleted: "reminder_completed"
        case .reminderUncompleted: "reminder_uncompleted"
        case .reminderUpdated: "reminder_updated"
        case .reminderDeleted: "reminder_deleted"
        case .reminderReordered: "reminder_reordered"
        case .reminderMovedToList: "reminder_moved_to_list"
        case .reminderScopeSelected: "reminder_scope_selected"
        case .reminderSortChanged: "reminder_sort_changed"
        case .reminderShowCompletedToggled: "reminder_show_completed_toggled"
        case .reminderListCreated: "reminder_list_created"
        case .reminderListUpdated: "reminder_list_updated"
        case .reminderListDeleted: "reminder_list_deleted"
        case .focusStarted: "focus_started"
        case .focusPaused: "focus_paused"
        case .focusResumed: "focus_resumed"
        case .focusSkipped: "focus_skipped"
        case .focusEnded: "focus_ended"
        case .focusCompleted: "focus_completed"
        case .focusPermissionDenied: "focus_permission_denied"
        case .focusPhaseAdvanced: "focus_phase_advanced"
        case .focusSessionCreated: "focus_session_created"
        case .focusSessionUpdated: "focus_session_updated"
        case .focusSessionDeleted: "focus_session_deleted"
        case .focusSessionSelected: "focus_session_selected"
        case .focusSessionLimitReached: "focus_session_limit_reached"
        case .paywallShown: "paywall_shown"
        case .paywallDismissed: "paywall_dismissed"
        case .planSelected: "plan_selected"
        case .purchaseAttempted: "purchase_attempted"
        case .purchaseResult: "purchase_result"
        case .restoreTapped: "restore_tapped"
        case .restoreResult: "restore_result"
        case .entitlementChanged: "entitlement_changed"
        case .premiumGateHit: "premium_gate_hit"
        case .termsTapped: "terms_tapped"
        case .privacyTapped: "privacy_tapped"
        case .productsLoadFailed: "products_load_failed"
        case .alwaysOnToggled: "always_on_toggled"
        case .showCalendarToggled: "show_calendar_toggled"
        case .textSizeChanged: "text_size_changed"
        case .displayModeChanged: "display_mode_changed"
        case .startTabChanged: "start_tab_changed"
        case .liveItemToggled: "live_item_toggled"
        case .liveScopeChanged: "live_scope_changed"
        case .liveColorChanged: "live_color_changed"
        case .tasksDefaultViewChanged: "tasks_default_view_changed"
        case .focusEndSoundToggled: "focus_end_sound_toggled"
        case .calendarVisibilityToggled: "calendar_visibility_toggled"
        case .calendarShowAllTapped: "calendar_show_all"
        case .live24hGuideOpened: "live_24h_guide_opened"
        case .forcedUpdatePrompted: "forced_update_prompted"
        case .forcedUpdateTapped: "forced_update_tapped"
        case .reviewRequested: "review_requested"
        case .feedbackTapped: "feedback_tapped"
        case .onboardingReplayTapped: "onboarding_replay_tapped"
        case .externalAppOpened: "external_app_opened"
        case .permissionSettingsOpened: "permission_settings_opened"
        }
    }

    /// GA4 이벤트 파라미터 — 값은 전부 문자열.
    var parameters: [String: String] {
        switch self {
        case .tabViewed(let tab): ["tab": tab]
        case .liveToggled(let kind, let on): ["kind": kind, "on": String(on)]
        case .liveDenied(let kind): ["kind": kind]
        case .liveCalendarShifted(let kind, let direction): ["kind": kind, "direction": direction]
        case .reminderCompleted(let source): ["source": source]
        case .reminderScopeSelected(let scope): ["scope": scope]
        case .reminderSortChanged(let key, let order): ["key": key, "order": order]
        case .reminderShowCompletedToggled(let on): ["on": String(on)]
        case .focusPaused(let source): ["source": source]
        case .focusResumed(let source): ["source": source]
        case .focusEnded(let source): ["source": source]
        case .focusPhaseAdvanced(let source): ["source": source]
        case .paywallShown(let source): ["source": source]
        case .planSelected(let plan): ["plan": plan]
        case .purchaseAttempted(let plan, let trial): ["plan": plan, "trial": String(trial)]
        case .purchaseResult(let plan, let outcome, let trial):
            ["plan": plan, "outcome": outcome, "trial": String(trial)]
        case .restoreResult(let outcome): ["outcome": outcome]
        case .entitlementChanged(let premium): ["premium": String(premium)]
        case .premiumGateHit(let feature): ["feature": feature]
        case .alwaysOnToggled(let on): ["on": String(on)]
        case .showCalendarToggled(let kind, let on): ["kind": kind, "on": String(on)]
        case .textSizeChanged(let size): ["size": size]
        case .displayModeChanged(let mode): ["mode": mode]
        case .startTabChanged(let tab): ["tab": tab]
        case .liveItemToggled(let kind, let on): ["kind": kind, "on": String(on)]
        case .liveScopeChanged(let scope): ["scope": scope]
        case .liveColorChanged(let kind): ["kind": kind]
        case .tasksDefaultViewChanged(let view): ["view": view]
        case .focusEndSoundToggled(let on): ["on": String(on)]
        case .calendarVisibilityToggled(let kind, let on): ["kind": kind, "on": String(on)]
        case .calendarShowAllTapped(let kind): ["kind": kind]
        case .reviewRequested(let source): ["source": source]
        case .externalAppOpened(let app): ["app": app]
        case .permissionSettingsOpened(let kind): ["kind": kind]
        default: [:]
        }
    }
}
