//
//  ReminderEditMappingTests.swift
//  cueTests
//

import EventKit
import Foundation
import Testing
@testable import cue

/// 할일 수정 저장 계약 — `ReminderMapper.apply`가 EKReminder에 쓰는 우선순위·위치 알림·마감 알람.
/// 핵심은 "도메인이 거칠게 표현하는 값은 바뀌었을 때만 재기록"과 "사용자가 단 알람 보존".
struct ReminderEditMappingTests {

    private let store = EKEventStore()

    private func time(_ hour: Int, _ minute: Int = 0) -> Date {
        DateComponents(calendar: .current, year: 2026, month: 8, day: 1, hour: hour, minute: minute).date!
    }

    private func makeChanges(
        dueDate: Date? = nil,
        includesTime: Bool = false,
        priority: ReminderPriority = .none,
        locationAlarm: ReminderLocationAlarm? = nil
    ) -> ReminderChanges {
        ReminderChanges(
            title: "할 일", notes: nil, dueDate: dueDate, includesTime: includesTime,
            recurrence: nil, priority: priority, locationAlarm: locationAlarm, listID: "L1"
        )
    }

    /// 마감 09:00(시각 지정) + cue가 단 09:00 알람이 있는 항목.
    private func makeTimedReminder() -> EKReminder {
        let reminder = EKReminder(eventStore: store)
        reminder.title = "할 일"
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: time(9)
        )
        reminder.addAlarm(EKAlarm(absoluteDate: time(9)))
        return reminder
    }

    private let home = ReminderLocationAlarm(
        title: "집", address: "서울시 어딘가 1", latitude: 37.5, longitude: 127.0,
        radius: 150, proximity: .arriving
    )

    // MARK: - 우선순위

    @Test func priorityFoldsEventKitIntegersIntoFourLevels() {
        #expect(ReminderMapper.toPriority(0) == ReminderPriority.none)
        #expect([1, 3, 4].map(ReminderMapper.toPriority) == [.high, .high, .high])
        #expect(ReminderMapper.toPriority(5) == .medium)
        #expect([6, 9].map(ReminderMapper.toPriority) == [.low, .low])
        // 쓰는 대표값은 다시 같은 단계로 읽힌다.
        for priority in ReminderPriority.allCases {
            #expect(ReminderMapper.toPriority(ReminderMapper.toEKPriority(priority)) == priority)
        }
    }

    /// 미리알림 앱에서 온 세분값(3)은 단계가 그대로면 1로 깎지 않는다. 단계가 바뀔 때만 대표값으로 쓴다.
    @Test func applyRewritesPriorityOnlyWhenLevelChanges() {
        let reminder = EKReminder(eventStore: store)
        reminder.priority = 3

        ReminderMapper.apply(makeChanges(priority: .high), to: reminder)
        #expect(reminder.priority == 3)

        ReminderMapper.apply(makeChanges(priority: .low), to: reminder)
        #expect(reminder.priority == 9)

        ReminderMapper.apply(makeChanges(priority: .none), to: reminder)
        #expect(reminder.priority == 0)
    }

    // MARK: - 위치 알림

    @Test func locationAlarmRoundTripsThroughEventKit() throws {
        let withAddress = ReminderMapper.toEKLocationAlarm(home)
        #expect(withAddress.proximity == .enter)
        #expect(withAddress.structuredLocation?.radius == 150)
        #expect(ReminderMapper.toLocationAlarm(withAddress) == home)

        // 주소·반경 없음(시스템 기본 반경), 출발.
        let office = ReminderLocationAlarm(
            title: "회사", address: nil, latitude: 37.4, longitude: 127.1, radius: nil, proximity: .leaving
        )
        let plain = ReminderMapper.toEKLocationAlarm(office)
        #expect(plain.proximity == .leave)
        #expect(plain.structuredLocation?.title == "회사")
        #expect(ReminderMapper.toLocationAlarm(plain) == office)
    }

    /// 표현하는 위치 알림만 교체·삭제한다 — 좌표 없는 위치 알람처럼 도메인이 못 읽는 것은 보존.
    @Test func applyReplacesOnlyRepresentedLocationAlarm() throws {
        let reminder = EKReminder(eventStore: store)
        let unreadable = EKAlarm(relativeOffset: 0)
        unreadable.structuredLocation = EKStructuredLocation(title: "좌표 없음")
        unreadable.proximity = .enter
        reminder.addAlarm(unreadable)
        reminder.addAlarm(ReminderMapper.toEKLocationAlarm(home))

        let office = ReminderLocationAlarm(
            title: "회사", address: nil, latitude: 37.4, longitude: 127.1, radius: nil, proximity: .leaving
        )
        ReminderMapper.apply(makeChanges(locationAlarm: office), to: reminder)
        #expect(ReminderMapper.representedLocationAlarm(in: reminder.alarms)?.domain == office)
        #expect(reminder.alarms?.count == 2)

        ReminderMapper.apply(makeChanges(locationAlarm: nil), to: reminder)
        #expect(ReminderMapper.representedLocationAlarm(in: reminder.alarms) == nil)
        let remaining = try #require(reminder.alarms)
        #expect(remaining.count == 1)
        #expect(remaining.first?.structuredLocation?.title == "좌표 없음")
    }

    // MARK: - 마감 알람 (사용자 알람 보존)

    /// 마감 시각을 옮기면 cue가 단(이전 마감 시각) 알람만 새 시각으로 바뀌고, 사용자가 단
    /// 다른 시각 절대 알람·상대 알람은 남는다 — 저장 때마다 사용자 알람이 지워지던 버그의 회귀 방지.
    @Test func applyMovesCueDueAlarmAndKeepsUserAlarms() throws {
        let reminder = makeTimedReminder()
        reminder.addAlarm(EKAlarm(absoluteDate: time(8)))       // 사용자: 다른 시각
        reminder.addAlarm(EKAlarm(relativeOffset: -600))        // 사용자: 10분 전

        ReminderMapper.apply(makeChanges(dueDate: time(10), includesTime: true), to: reminder)

        let alarms = try #require(reminder.alarms)
        #expect(Set(alarms.compactMap(\.absoluteDate)) == [time(8), time(10)])
        #expect(alarms.contains { $0.absoluteDate == nil && $0.relativeOffset == -600 })
        #expect(alarms.count == 3)
    }

    /// 시각 지정을 끄면 cue 마감 알람만 빠지고 새로 달지 않는다. 사용자 알람은 그대로.
    @Test func applyDropsCueDueAlarmWhenTimeRemoved() throws {
        let reminder = makeTimedReminder()
        reminder.addAlarm(EKAlarm(absoluteDate: time(8)))

        ReminderMapper.apply(makeChanges(dueDate: time(9), includesTime: false), to: reminder)

        let alarms = try #require(reminder.alarms)
        #expect(alarms.compactMap(\.absoluteDate) == [time(8)])
        #expect(reminder.dueDateComponents?.hour == nil)
    }
}
