//
//  SnapshotCacheRepositoryTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 첫 페인트용 스냅샷 캐시 — 마지막 fetch 결과를 저장하고 앱 재시작 시 그대로 복원한다.
struct SnapshotCacheRepositoryTests {

    private func makeRepo() -> UserDefaultsSnapshotCacheRepository {
        UserDefaultsSnapshotCacheRepository(
            defaults: UserDefaults(suiteName: "test.snapshotCache.\(UUID().uuidString)")!
        )
    }

    /// 할일 스냅샷 — 리스트·항목(마감일·반복·생성일 포함)을 JSON round-trip으로 복원한다.
    @Test func remindersSnapshotRoundTrips() async {
        let repo = makeRepo()
        let snapshot = RemindersSnapshot(
            lists: [
                ReminderList(id: "A", title: "회사", colorHex: "#FF9500", isDefault: true),
                ReminderList(id: "B", title: "개인", colorHex: nil),
            ],
            reminders: [
                Reminder(
                    id: "r1", title: "보고서", isCompleted: false, notes: "메모",
                    dueDate: Date(timeIntervalSince1970: 1_800_000_000), includesTime: true,
                    recurrence: RecurrenceRule(frequency: .weekly, interval: 2),
                    creationDate: Date(timeIntervalSince1970: 1_700_000_000), listID: "A"
                ),
                Reminder(id: "r2", title: "장보기", isCompleted: true,
                         notes: nil, dueDate: nil, listID: "B"),
            ]
        )

        await repo.saveRemindersSnapshot(snapshot)

        #expect(await repo.loadRemindersSnapshot() == snapshot)
    }

    /// 일정 스냅샷 — 이벤트와 fetch 범위 끝(fetchedUntil)을 함께 복원한다.
    @Test func eventsSnapshotRoundTrips() async {
        let repo = makeRepo()
        let snapshot = EventsSnapshot(
            events: [
                CalendarEvent(
                    id: "e1", title: "회의",
                    startDate: Date(timeIntervalSince1970: 1_800_000_000),
                    endDate: Date(timeIntervalSince1970: 1_800_003_600),
                    isAllDay: false, calendarColorHex: "#0A84FF",
                    isReadOnly: true, calendarID: "cal1"
                ),
            ],
            fetchedUntil: Date(timeIntervalSince1970: 1_802_000_000)
        )

        await repo.saveEventsSnapshot(snapshot)

        #expect(await repo.loadEventsSnapshot() == snapshot)
    }

    /// 저장된 적 없으면 nil — 호출자가 "캐시 없음 = 기존 스피너 경로"로 분기한다.
    @Test func loadReturnsNilWhenEmpty() async {
        let repo = makeRepo()
        #expect(await repo.loadRemindersSnapshot() == nil)
        #expect(await repo.loadEventsSnapshot() == nil)
    }

    /// 다시 저장하면 이전 스냅샷을 대체한다 — 항상 마지막 fetch 결과만 유지.
    @Test func saveOverwritesPreviousSnapshot() async {
        let repo = makeRepo()
        await repo.saveRemindersSnapshot(RemindersSnapshot(
            lists: [ReminderList(id: "A", title: "old", colorHex: nil)], reminders: []
        ))
        let newer = RemindersSnapshot(
            lists: [ReminderList(id: "B", title: "new", colorHex: nil)], reminders: []
        )

        await repo.saveRemindersSnapshot(newer)

        #expect(await repo.loadRemindersSnapshot() == newer)
    }

    /// 할일·일정 스냅샷은 서로 독립 — 한쪽 저장이 다른 쪽을 건드리지 않는다.
    @Test func remindersAndEventsAreIndependent() async {
        let repo = makeRepo()
        let reminders = RemindersSnapshot(lists: [], reminders: [
            Reminder(id: "r", title: "t", isCompleted: false, notes: nil, dueDate: nil, listID: "A"),
        ])

        await repo.saveRemindersSnapshot(reminders)

        #expect(await repo.loadEventsSnapshot() == nil)
        #expect(await repo.loadRemindersSnapshot() == reminders)
    }
}
