//
//  AnalyticsEventTests.swift
//  cueTests
//

import Testing
@testable import cue

struct AnalyticsEventTests {

    // MARK: - 이름 매핑

    @Test func tabViewedName() {
        #expect(AnalyticsEvent.tabViewed(tab: "memo").name == "tab_viewed")
    }

    @Test func liveEventNames() {
        #expect(AnalyticsEvent.liveToggled(kind: "memo", on: true).name == "live_toggled")
        #expect(AnalyticsEvent.liveDenied(kind: "tasks").name == "live_denied")
    }

    @Test func contentEventNames() {
        #expect(AnalyticsEvent.memoSaved.name == "memo_saved")
        #expect(AnalyticsEvent.memoCleared.name == "memo_cleared")
        #expect(AnalyticsEvent.eventCreated.name == "event_created")
        #expect(AnalyticsEvent.eventUpdated.name == "event_updated")
        #expect(AnalyticsEvent.eventDeleted.name == "event_deleted")
        #expect(AnalyticsEvent.reminderCreated.name == "reminder_created")
        #expect(AnalyticsEvent.reminderCompleted(source: "app").name == "reminder_completed")
        #expect(AnalyticsEvent.reminderUncompleted.name == "reminder_uncompleted")
        #expect(AnalyticsEvent.reminderUpdated.name == "reminder_updated")
        #expect(AnalyticsEvent.reminderDeleted.name == "reminder_deleted")
        #expect(AnalyticsEvent.reminderReordered.name == "reminder_reordered")
        #expect(AnalyticsEvent.reminderMovedToList.name == "reminder_moved_to_list")
        #expect(AnalyticsEvent.reminderScopeSelected(scope: "today").name == "reminder_scope_selected")
        #expect(AnalyticsEvent.reminderSortChanged(key: "dueDate", order: "ascending").name
                == "reminder_sort_changed")
        #expect(AnalyticsEvent.reminderShowCompletedToggled(on: true).name
                == "reminder_show_completed_toggled")
        #expect(AnalyticsEvent.reminderListCreated.name == "reminder_list_created")
        #expect(AnalyticsEvent.reminderListUpdated.name == "reminder_list_updated")
        #expect(AnalyticsEvent.reminderListDeleted.name == "reminder_list_deleted")
    }

    @Test func focusEventNames() {
        #expect(AnalyticsEvent.focusStarted.name == "focus_started")
        #expect(AnalyticsEvent.focusPaused(source: "app").name == "focus_paused")
        #expect(AnalyticsEvent.focusResumed(source: "app").name == "focus_resumed")
        #expect(AnalyticsEvent.focusSkipped.name == "focus_skipped")
        #expect(AnalyticsEvent.focusEnded(source: "app").name == "focus_ended")
        #expect(AnalyticsEvent.focusCompleted.name == "focus_completed")
        #expect(AnalyticsEvent.focusPermissionDenied.name == "focus_permission_denied")
        #expect(AnalyticsEvent.focusPhaseAdvanced(source: "live_activity").name == "focus_phase_advanced")
        #expect(AnalyticsEvent.focusSessionCreated.name == "focus_session_created")
        #expect(AnalyticsEvent.focusSessionUpdated.name == "focus_session_updated")
        #expect(AnalyticsEvent.focusSessionDeleted.name == "focus_session_deleted")
        #expect(AnalyticsEvent.focusSessionSelected.name == "focus_session_selected")
        #expect(AnalyticsEvent.focusSessionLimitReached.name == "focus_session_limit_reached")
    }

    @Test func liveEventExtraNames() {
        #expect(AnalyticsEvent.liveCalendarShifted(kind: "memo", direction: "next").name
                == "live_calendar_shifted")
    }

    @Test func premiumEventNames() {
        #expect(AnalyticsEvent.paywallShown(source: "banner").name == "paywall_shown")
        #expect(AnalyticsEvent.paywallDismissed.name == "paywall_dismissed")
        #expect(AnalyticsEvent.planSelected(plan: "monthly").name == "plan_selected")
        #expect(AnalyticsEvent.purchaseAttempted(plan: "yearly", trial: true).name == "purchase_attempted")
        #expect(AnalyticsEvent.purchaseResult(plan: "yearly", outcome: "success", trial: true).name
                == "purchase_result")
        #expect(AnalyticsEvent.restoreTapped.name == "restore_tapped")
        #expect(AnalyticsEvent.restoreResult(outcome: "success").name == "restore_result")
        #expect(AnalyticsEvent.entitlementChanged(premium: true).name == "entitlement_changed")
        #expect(AnalyticsEvent.premiumGateHit(feature: "live_color").name == "premium_gate_hit")
        #expect(AnalyticsEvent.termsTapped.name == "terms_tapped")
        #expect(AnalyticsEvent.privacyTapped.name == "privacy_tapped")
        #expect(AnalyticsEvent.productsLoadFailed.name == "products_load_failed")
    }

    @Test func settingsEventNames() {
        #expect(AnalyticsEvent.alwaysOnToggled(on: true).name == "always_on_toggled")
        #expect(AnalyticsEvent.showCalendarToggled(kind: "memo", on: false).name == "show_calendar_toggled")
        #expect(AnalyticsEvent.textSizeChanged(size: "medium").name == "text_size_changed")
        #expect(AnalyticsEvent.displayModeChanged(mode: "dark").name == "display_mode_changed")
        #expect(AnalyticsEvent.startTabChanged(tab: "focus").name == "start_tab_changed")
        #expect(AnalyticsEvent.liveItemToggled(kind: "memo", on: true).name == "live_item_toggled")
        #expect(AnalyticsEvent.liveScopeChanged(scope: "today").name == "live_scope_changed")
        #expect(AnalyticsEvent.liveColorChanged(kind: "background").name == "live_color_changed")
        #expect(AnalyticsEvent.tasksDefaultViewChanged(view: "today").name == "tasks_default_view_changed")
        #expect(AnalyticsEvent.focusEndSoundToggled(on: false).name == "focus_end_sound_toggled")
        #expect(AnalyticsEvent.calendarVisibilityToggled(kind: "calendar", on: true).name
                == "calendar_visibility_toggled")
        #expect(AnalyticsEvent.calendarShowAllTapped(kind: "reminder_list").name == "calendar_show_all")
        #expect(AnalyticsEvent.live24hGuideOpened.name == "live_24h_guide_opened")
    }

    @Test func appEventNames() {
        #expect(AnalyticsEvent.forcedUpdatePrompted.name == "forced_update_prompted")
        #expect(AnalyticsEvent.forcedUpdateTapped.name == "forced_update_tapped")
        #expect(AnalyticsEvent.reviewRequested.name == "review_requested")
        #expect(AnalyticsEvent.feedbackTapped.name == "feedback_tapped")
        #expect(AnalyticsEvent.externalAppOpened(app: "calendar").name == "external_app_opened")
        #expect(AnalyticsEvent.permissionSettingsOpened(kind: "reminder").name
                == "permission_settings_opened")
    }

    // MARK: - 파라미터 매핑

    @Test func tabViewedParameters() {
        #expect(AnalyticsEvent.tabViewed(tab: "focus").parameters == ["tab": "focus"])
    }

    @Test func liveToggledParameters() {
        #expect(AnalyticsEvent.liveToggled(kind: "schedule", on: true).parameters
                == ["kind": "schedule", "on": "true"])
        #expect(AnalyticsEvent.liveToggled(kind: "memo", on: false).parameters
                == ["kind": "memo", "on": "false"])
    }

    @Test func purchaseParameters() {
        // trial 파라미터 — 트라이얼 시작과 일반 결제를 전환 분석에서 구분한다.
        #expect(AnalyticsEvent.purchaseAttempted(plan: "lifetime", trial: false).parameters
                == ["plan": "lifetime", "trial": "false"])
        #expect(AnalyticsEvent.purchaseResult(plan: "monthly", outcome: "cancelled", trial: true).parameters
                == ["plan": "monthly", "outcome": "cancelled", "trial": "true"])
    }

    @Test func parameterFreeEventsHaveEmptyParameters() {
        #expect(AnalyticsEvent.memoSaved.parameters.isEmpty)
        #expect(AnalyticsEvent.memoCleared.parameters.isEmpty)
        #expect(AnalyticsEvent.focusStarted.parameters.isEmpty)
        #expect(AnalyticsEvent.focusCompleted.parameters.isEmpty)
        #expect(AnalyticsEvent.restoreTapped.parameters.isEmpty)
        #expect(AnalyticsEvent.reminderListCreated.parameters.isEmpty)
        #expect(AnalyticsEvent.forcedUpdatePrompted.parameters.isEmpty)
    }

    @Test func settingsParameters() {
        #expect(AnalyticsEvent.showCalendarToggled(kind: "tasks", on: true).parameters
                == ["kind": "tasks", "on": "true"])
        #expect(AnalyticsEvent.textSizeChanged(size: "small").parameters == ["size": "small"])
        #expect(AnalyticsEvent.paywallShown(source: "banner").parameters == ["source": "banner"])
        #expect(AnalyticsEvent.displayModeChanged(mode: "system").parameters == ["mode": "system"])
        #expect(AnalyticsEvent.startTabChanged(tab: "memo").parameters == ["tab": "memo"])
        #expect(AnalyticsEvent.liveItemToggled(kind: "tasks", on: false).parameters
                == ["kind": "tasks", "on": "false"])
        #expect(AnalyticsEvent.liveScopeChanged(scope: "all").parameters == ["scope": "all"])
        #expect(AnalyticsEvent.liveColorChanged(kind: "font").parameters == ["kind": "font"])
        #expect(AnalyticsEvent.tasksDefaultViewChanged(view: "upcoming").parameters
                == ["view": "upcoming"])
        #expect(AnalyticsEvent.focusEndSoundToggled(on: true).parameters == ["on": "true"])
        #expect(AnalyticsEvent.calendarVisibilityToggled(kind: "calendar", on: false).parameters
                == ["kind": "calendar", "on": "false"])
        #expect(AnalyticsEvent.calendarShowAllTapped(kind: "calendar").parameters
                == ["kind": "calendar"])
    }

    @Test func sourceTaggedEventParameters() {
        #expect(AnalyticsEvent.reminderCompleted(source: "live_activity").parameters
                == ["source": "live_activity"])
        #expect(AnalyticsEvent.focusPaused(source: "app").parameters == ["source": "app"])
        #expect(AnalyticsEvent.focusResumed(source: "live_activity").parameters
                == ["source": "live_activity"])
        #expect(AnalyticsEvent.focusEnded(source: "app").parameters == ["source": "app"])
        #expect(AnalyticsEvent.focusPhaseAdvanced(source: "live_activity").parameters
                == ["source": "live_activity"])
    }

    @Test func reminderDetailParameters() {
        #expect(AnalyticsEvent.reminderScopeSelected(scope: "list").parameters == ["scope": "list"])
        #expect(AnalyticsEvent.reminderSortChanged(key: "title", order: "descending").parameters
                == ["key": "title", "order": "descending"])
        #expect(AnalyticsEvent.reminderShowCompletedToggled(on: false).parameters == ["on": "false"])
    }

    @Test func liveCalendarShiftedParameters() {
        #expect(AnalyticsEvent.liveCalendarShifted(kind: "schedule", direction: "previous").parameters
                == ["kind": "schedule", "direction": "previous"])
    }

    @Test func premiumDetailParameters() {
        #expect(AnalyticsEvent.planSelected(plan: "lifetime").parameters == ["plan": "lifetime"])
        #expect(AnalyticsEvent.restoreResult(outcome: "failure").parameters == ["outcome": "failure"])
        #expect(AnalyticsEvent.entitlementChanged(premium: false).parameters == ["premium": "false"])
        #expect(AnalyticsEvent.premiumGateHit(feature: "focus_session_limit").parameters
                == ["feature": "focus_session_limit"])
    }

    @Test func appDetailParameters() {
        #expect(AnalyticsEvent.externalAppOpened(app: "shortcuts").parameters == ["app": "shortcuts"])
        #expect(AnalyticsEvent.permissionSettingsOpened(kind: "schedule").parameters
                == ["kind": "schedule"])
    }
}
