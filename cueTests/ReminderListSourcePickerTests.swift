//
//  ReminderListSourcePickerTests.swift
//  cueTests
//

import Testing
@testable import cue

/// 새 미리알림 리스트를 만들 계정(source) 선택 — 이름이 아니라 **능력(미리알림 지원) 기준**.
/// "iCloud라는 이름"만 보고 고르면 iCloud 미리알림 동기화가 꺼진 기기에서
/// "해당 계정은 미리 알림을 지원하지 않습니다" 저장 실패가 난다(실기기 재현 버그).
struct ReminderListSourcePickerTests {

    private func candidate(
        _ id: String, isICloud: Bool = false, hasReminderCalendars: Bool = false
    ) -> ReminderListSourcePicker.Candidate {
        .init(id: id, isICloud: isICloud, hasReminderCalendars: hasReminderCalendars)
    }

    /// 1순위: 기본 미리알림 리스트의 source — 사용자가 실제 미리알림을 쓰는 계정이라 항상 안전.
    @Test func defaultSourceWinsOverICloud() {
        let picked = ReminderListSourcePicker.pick(
            from: [
                candidate("icloud", isICloud: true, hasReminderCalendars: true),
                candidate("local", hasReminderCalendars: true),
            ],
            defaultSourceID: "local"
        )
        #expect(picked == "local")
    }

    /// 2순위: 기본이 없으면 미리알림 리스트를 실제로 가진 iCloud.
    @Test func iCloudWithRemindersWinsWhenNoDefault() {
        let picked = ReminderListSourcePicker.pick(
            from: [
                candidate("exchange", hasReminderCalendars: true),
                candidate("icloud", isICloud: true, hasReminderCalendars: true),
            ],
            defaultSourceID: nil
        )
        #expect(picked == "icloud")
    }

    /// 핵심 버그 시나리오 — iCloud 미리알림 동기화 OFF: 이름은 iCloud지만 미리알림 리스트가
    /// 없으면 선택하지 않고, 미리알림을 가진 다른 계정으로 간다.
    @Test func skipsICloudWithoutReminderSupport() {
        let picked = ReminderListSourcePicker.pick(
            from: [
                candidate("icloud", isICloud: true, hasReminderCalendars: false),
                candidate("local", hasReminderCalendars: true),
            ],
            defaultSourceID: nil
        )
        #expect(picked == "local")
    }

    /// 기본 source id가 후보에 없으면(스테일) 다음 순위로 넘어간다.
    @Test func staleDefaultFallsThrough() {
        let picked = ReminderListSourcePicker.pick(
            from: [candidate("local", hasReminderCalendars: true)],
            defaultSourceID: "gone"
        )
        #expect(picked == "local")
    }

    /// 미리알림을 지원하는 계정이 하나도 없으면 nil — 호출처가 안내 에러를 던진다.
    /// (아무 source나 찍던 기존 blind fallback이 이 버그의 공범 — 제거.)
    @Test func returnsNilWhenNothingSupportsReminders() {
        let picked = ReminderListSourcePicker.pick(
            from: [
                candidate("icloud", isICloud: true, hasReminderCalendars: false),
                candidate("holiday", hasReminderCalendars: false),
            ],
            defaultSourceID: nil
        )
        #expect(picked == nil)
    }
}
