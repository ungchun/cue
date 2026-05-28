//
//  EventsUseCaseTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct EventsUseCaseTests {

    @Test func requestAccessGrantsWhenNotDetermined() async {
        let repository = InMemoryEventsRepository(access: .notDetermined)

        let result = await RequestEventsAccessUseCase(repository: repository)()

        #expect(result == .granted)
    }

    @Test func requestAccessKeepsDeniedState() async {
        let repository = InMemoryEventsRepository(access: .denied)

        let result = await RequestEventsAccessUseCase(repository: repository)()

        #expect(result == .denied)
    }

    @Test func requestAccessKeepsGrantedState() async {
        let repository = InMemoryEventsRepository(access: .granted)

        let result = await RequestEventsAccessUseCase(repository: repository)()

        #expect(result == .granted)
    }
}
