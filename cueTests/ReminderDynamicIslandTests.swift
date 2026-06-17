//
//  ReminderDynamicIslandTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct ReminderDynamicIslandTests {

    private func item(_ id: String) -> LiveReminderItem {
        LiveReminderItem(id: id, title: "T\(id)", colorHex: nil)
    }

    @Test func incompleteCountAddsRemaining() {
        let state = ReminderLiveActivityAttributes.ContentState(
            items: [item("a"), item("b")], remaining: 3
        )
        #expect(ReminderDynamicIsland.incompleteCount(state) == 5)
    }

    @Test func incompleteCountIsItemsOnlyWhenNoRemaining() {
        let state = ReminderLiveActivityAttributes.ContentState(
            items: [item("a")], remaining: 0
        )
        #expect(ReminderDynamicIsland.incompleteCount(state) == 1)
    }
}
