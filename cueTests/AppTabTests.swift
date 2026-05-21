//
//  AppTabTests.swift
//  cueTests
//

import Testing
@testable import cue

struct AppTabTests {

    @Test func allCasesAreOrderedReminderThenSettings() {
        #expect(AppTab.allCases == [.reminder, .settings])
    }

    @Test func eachTabExposesItsTitle() {
        #expect(AppTab.reminder.title == "미리알림")
        #expect(AppTab.settings.title == "설정")
    }

    @Test func everyTabHasANonEmptySystemImage() {
        for tab in AppTab.allCases {
            #expect(!tab.systemImage.isEmpty)
        }
    }
}
