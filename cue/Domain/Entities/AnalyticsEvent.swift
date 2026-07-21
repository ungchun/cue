//
//  AnalyticsEvent.swift
//  cue / Domain
//

/// 앱이 기록하는 분석 이벤트 — 이름·파라미터 매핑을 한곳에 모은 순수 모델.
///
/// 케이스를 추가하면 `name`/`parameters`가 곧 GA4 이벤트 스키마다. 이름은 snake_case
/// (GA4 관례), 파라미터 값은 전부 문자열로 통일해 대시보드에서 일관되게 읽히게 한다.
/// Firebase 전송은 Data 계층(`FirebaseAnalyticsService`)이 담당 — Domain은 SDK를 모른다.
enum AnalyticsEvent: Equatable, Sendable {
    // 화면
    case tabViewed(tab: String)

    // 라이브 액티비티
    case liveToggled(kind: String, on: Bool)
    case liveDenied(kind: String)

    // 콘텐츠
    case memoSaved
    case eventCreated
    case reminderCreated
    case reminderCompleted

    // 집중
    case focusStarted
    case focusPaused
    case focusResumed
    case focusSkipped
    case focusEnded
    case focusSessionCreated
    case focusSessionUpdated
    case focusSessionDeleted

    // 프리미엄
    case paywallShown(source: String)
    case purchaseAttempted(plan: String)
    case purchaseResult(plan: String, outcome: String)
    case restoreTapped

    // 설정
    case alwaysOnToggled(on: Bool)
    case showCalendarToggled(kind: String, on: Bool)
    case textSizeChanged(size: String)

    /// GA4 이벤트 이름.
    var name: String {
        switch self {
        case .tabViewed: "tab_viewed"
        case .liveToggled: "live_toggled"
        case .liveDenied: "live_denied"
        case .memoSaved: "memo_saved"
        case .eventCreated: "event_created"
        case .reminderCreated: "reminder_created"
        case .reminderCompleted: "reminder_completed"
        case .focusStarted: "focus_started"
        case .focusPaused: "focus_paused"
        case .focusResumed: "focus_resumed"
        case .focusSkipped: "focus_skipped"
        case .focusEnded: "focus_ended"
        case .focusSessionCreated: "focus_session_created"
        case .focusSessionUpdated: "focus_session_updated"
        case .focusSessionDeleted: "focus_session_deleted"
        case .paywallShown: "paywall_shown"
        case .purchaseAttempted: "purchase_attempted"
        case .purchaseResult: "purchase_result"
        case .restoreTapped: "restore_tapped"
        case .alwaysOnToggled: "always_on_toggled"
        case .showCalendarToggled: "show_calendar_toggled"
        case .textSizeChanged: "text_size_changed"
        }
    }

    /// GA4 이벤트 파라미터 — 값은 전부 문자열.
    var parameters: [String: String] {
        switch self {
        case .tabViewed(let tab): ["tab": tab]
        case .liveToggled(let kind, let on): ["kind": kind, "on": String(on)]
        case .liveDenied(let kind): ["kind": kind]
        case .paywallShown(let source): ["source": source]
        case .purchaseAttempted(let plan): ["plan": plan]
        case .purchaseResult(let plan, let outcome): ["plan": plan, "outcome": outcome]
        case .alwaysOnToggled(let on): ["on": String(on)]
        case .showCalendarToggled(let kind, let on): ["kind": kind, "on": String(on)]
        case .textSizeChanged(let size): ["size": size]
        default: [:]
        }
    }
}
