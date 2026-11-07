//
//  MonthEventsSnapshotTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 월 캘린더 스냅샷 캐시 — 달별 일정을 저장하고 앱 재시작 시 그대로 복원한다.
struct MonthEventsSnapshotTests {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.monthSnapshot.\(UUID().uuidString)")!
    }

    private func event(_ id: String, at seconds: TimeInterval) -> CalendarEvent {
        CalendarEvent(
            id: id, title: "일정 \(id)",
            startDate: Date(timeIntervalSince1970: seconds),
            endDate: Date(timeIntervalSince1970: seconds + 3600),
            isAllDay: false, calendarColorHex: "#0A84FF",
            isReadOnly: false, calendarID: "cal1"
        )
    }

    private func sampleSnapshot() -> MonthEventsSnapshot {
        // 서로 다른 달 1일 자정을 키로 — 비-String 키 딕셔너리가 JSON에서 보존되는지 본다.
        MonthEventsSnapshot(months: [
            Date(timeIntervalSince1970: 1_798_761_600): [event("jan", at: 1_798_800_000)],
            Date(timeIntervalSince1970: 1_801_440_000): [event("feb1", at: 1_801_500_000), event("feb2", at: 1_801_600_000)],
            Date(timeIntervalSince1970: 1_803_859_200): [],
        ])
    }

    /// 여러 달의 `[Date: [CalendarEvent]]`가 JSON 왕복 후에도 키·값 그대로 복원된다.
    @Test func monthEventsSnapshotRoundTripsMultipleMonths() async {
        let repo = UserDefaultsSnapshotCacheRepository(defaults: makeDefaults())
        let snapshot = sampleSnapshot()

        await repo.saveMonthEventsSnapshot(snapshot)

        let loaded = await repo.loadMonthEventsSnapshot()
        #expect(loaded == snapshot)
        #expect(loaded?.months.count == 3)
        #expect(loaded?.months[Date(timeIntervalSince1970: 1_801_440_000)]?.map(\.id) == ["feb1", "feb2"])
    }

    /// 저장된 적 없으면 nil — 호출자가 스피너 경로로 분기한다.
    @Test func loadMonthEventsSnapshotReturnsNilWhenEmpty() async {
        let repo = UserDefaultsSnapshotCacheRepository(defaults: makeDefaults())
        #expect(await repo.loadMonthEventsSnapshot() == nil)
    }

    /// 깨진 데이터는 복구 시도 없이 nil.
    @Test func loadMonthEventsSnapshotReturnsNilForCorruptData() async {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: "cue.snapshot.monthEvents.v1")
        let repo = UserDefaultsSnapshotCacheRepository(defaults: defaults)

        #expect(await repo.loadMonthEventsSnapshot() == nil)
    }

    /// 다시 저장하면 이전 스냅샷을 대체한다.
    @Test func saveMonthEventsSnapshotOverwritesPrevious() async {
        let repo = UserDefaultsSnapshotCacheRepository(defaults: makeDefaults())
        await repo.saveMonthEventsSnapshot(sampleSnapshot())
        let newer = MonthEventsSnapshot(months: [
            Date(timeIntervalSince1970: 1_798_761_600): [event("new", at: 1_798_900_000)],
        ])

        await repo.saveMonthEventsSnapshot(newer)

        #expect(await repo.loadMonthEventsSnapshot() == newer)
    }

    /// 월 스냅샷은 기존 일정·할일 스냅샷과 독립 — 서로 덮어쓰지 않는다.
    @Test func monthEventsSnapshotIsIndependentOfOtherSnapshots() async {
        let repo = UserDefaultsSnapshotCacheRepository(defaults: makeDefaults())

        await repo.saveMonthEventsSnapshot(sampleSnapshot())

        #expect(await repo.loadEventsSnapshot() == nil)
        #expect(await repo.loadRemindersSnapshot() == nil)
    }

    /// 유스케이스 왕복 — Save로 넣은 스냅샷을 Load가 그대로 돌려준다.
    @Test func useCasesRoundTrip() async {
        let repo = InMemorySnapshotCacheRepository()
        let load = LoadMonthEventsSnapshotUseCase(repository: repo)
        let save = SaveMonthEventsSnapshotUseCase(repository: repo)
        let snapshot = sampleSnapshot()

        #expect(await load() == nil)
        await save(snapshot)

        #expect(await load() == snapshot)
        #expect(await repo.monthEventsSnapshot == snapshot)
    }
}
