//
//  StartSampleLiveActivitiesUseCase.swift
//  cue / Domain
//

import Foundation

/// 온보딩 첫 큐 게시에 곁들이는 **예시** 일정·할일 라이브 액티비티 — 잠금화면에서
/// 메모(진짜) + 일정 + 할일 3카드가 함께 뜨는 제품의 대표 장면을 권한·실데이터 없이 보여준다.
///
/// - 문구는 대놓고 예시("예시 일정"류) — 잠금화면은 앱 밖이라, 그럴싸한 가짜가 진짜 데이터로
///   오인되면 혼란("내 캘린더에 이게 왜 있지")을 만든다.
/// - 할일 id는 합성 접두사 — EventKit 식별자와 절대 겹치지 않아 체크 인텐트
///   (`CompleteReminderIntent`)가 조회 실패로 자연히 no-op이 된다(별도 가드 불필요).
/// - 일정은 캘린더 오버라이드로 월간 캘린더까지 강제 표시 — 설정 미러를 건드리지 않는다.
/// - 쿼터(`ConsumeLiveActivation`) 미소비 — 첫 큐 게시와 같은 이유로 무료 한도를 갉지 않는다.
/// - best-effort: 목업은 조연이라 하나가 실패해도 나머지·메모 게시에 영향을 주지 않는다.
struct StartSampleLiveActivitiesUseCase: Sendable {
    let startSchedule: StartScheduleLiveActivityUseCase
    let startReminder: StartReminderLiveActivityUseCase

    /// 예시 할일 id 접두사 — 실제 EventKit 식별자 형식과 절대 안 겹치는 앱 고유 네임스페이스.
    static let sampleReminderIDPrefix = "cue.sample.reminder."
    /// 예시 할일 개수 — 위젯 잠금화면 표시 한도(6칸)를 꽉 채워 실사용 밀도를 보여준다.
    static let sampleTaskCount = 6

    func callAsFunction(now: Date = .now) async {
        // 실패는 삼킨다 — 온보딩 화면은 조용히 머무는 게 에러 알림보다 낫고(메모와 동일 정책),
        // 일정이 실패해도 할일은 계속 시도한다.
        try? await startSchedule(events: Self.sampleEvents(now: now), now: now, showsCalendarOverride: true)
        try? await startReminder(
            listTitle: String(localized: "Sample"),
            reminders: Self.sampleReminders(),
            listColors: [:],
            now: now
        )
    }

    /// 오늘 하루 묶음 — 종일 캡슐 1 + 시간 막대 2로 일정 카드의 두 표시 형태를 다 보여준다.
    /// 시간 이벤트는 now 이후로 잡아 use case의 "지난 일정 숨김" 필터에 걸리지 않게 한다.
    static func sampleEvents(now: Date) -> [CalendarEvent] {
        let todayStart = Calendar.current.startOfDay(for: now)
        return [
            CalendarEvent(
                id: "cue.sample.event.allday",
                title: String(localized: "Sample all-day event"),
                startDate: todayStart,
                endDate: todayStart.addingTimeInterval(86_400),
                isAllDay: true,
                calendarColorHex: nil,
                isReadOnly: true
            ),
            CalendarEvent(
                id: "cue.sample.event.1",
                title: String(localized: "Sample event 1"),
                startDate: now.addingTimeInterval(3_600),
                endDate: now.addingTimeInterval(7_200),
                isAllDay: false,
                calendarColorHex: nil,
                isReadOnly: true
            ),
            CalendarEvent(
                id: "cue.sample.event.2",
                title: String(localized: "Sample event 2"),
                startDate: now.addingTimeInterval(10_800),
                endDate: now.addingTimeInterval(14_400),
                isAllDay: false,
                calendarColorHex: nil,
                isReadOnly: true
            ),
        ]
    }

    /// 예시 할일 6개 — 마감 미지정(전부 "오늘" 카운트에 포함), 리스트 색 없음(시스템 색 폴백).
    static func sampleReminders() -> [Reminder] {
        (1...sampleTaskCount).map { index in
            Reminder(
                id: "\(sampleReminderIDPrefix)\(index)",
                title: String(localized: "Sample task \(index)"),
                isCompleted: false,
                notes: nil,
                dueDate: nil,
                listID: "cue.sample.list"
            )
        }
    }
}
