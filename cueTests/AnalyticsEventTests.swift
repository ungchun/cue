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
        #expect(AnalyticsEvent.eventCreated.name == "event_created")
        #expect(AnalyticsEvent.reminderCreated.name == "reminder_created")
        #expect(AnalyticsEvent.reminderCompleted.name == "reminder_completed")
    }

    @Test func focusEventNames() {
        #expect(AnalyticsEvent.focusStarted.name == "focus_started")
        #expect(AnalyticsEvent.focusPaused.name == "focus_paused")
        #expect(AnalyticsEvent.focusResumed.name == "focus_resumed")
        #expect(AnalyticsEvent.focusSkipped.name == "focus_skipped")
        #expect(AnalyticsEvent.focusEnded.name == "focus_ended")
        #expect(AnalyticsEvent.focusSessionCreated.name == "focus_session_created")
        #expect(AnalyticsEvent.focusSessionUpdated.name == "focus_session_updated")
        #expect(AnalyticsEvent.focusSessionDeleted.name == "focus_session_deleted")
    }

    @Test func premiumEventNames() {
        #expect(AnalyticsEvent.paywallShown(source: "banner").name == "paywall_shown")
        #expect(AnalyticsEvent.purchaseAttempted(plan: "yearly").name == "purchase_attempted")
        #expect(AnalyticsEvent.purchaseResult(plan: "yearly", outcome: "success").name == "purchase_result")
        #expect(AnalyticsEvent.restoreTapped.name == "restore_tapped")
    }

    @Test func settingsEventNames() {
        #expect(AnalyticsEvent.alwaysOnToggled(on: true).name == "always_on_toggled")
        #expect(AnalyticsEvent.showCalendarToggled(kind: "memo", on: false).name == "show_calendar_toggled")
        #expect(AnalyticsEvent.textSizeChanged(size: "medium").name == "text_size_changed")
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
        #expect(AnalyticsEvent.purchaseAttempted(plan: "lifetime").parameters == ["plan": "lifetime"])
        #expect(AnalyticsEvent.purchaseResult(plan: "monthly", outcome: "cancelled").parameters
                == ["plan": "monthly", "outcome": "cancelled"])
    }

    @Test func parameterFreeEventsHaveEmptyParameters() {
        #expect(AnalyticsEvent.memoSaved.parameters.isEmpty)
        #expect(AnalyticsEvent.focusStarted.parameters.isEmpty)
        #expect(AnalyticsEvent.restoreTapped.parameters.isEmpty)
    }

    @Test func settingsParameters() {
        #expect(AnalyticsEvent.showCalendarToggled(kind: "tasks", on: true).parameters
                == ["kind": "tasks", "on": "true"])
        #expect(AnalyticsEvent.textSizeChanged(size: "small").parameters == ["size": "small"])
        #expect(AnalyticsEvent.paywallShown(source: "banner").parameters == ["source": "banner"])
    }
}
