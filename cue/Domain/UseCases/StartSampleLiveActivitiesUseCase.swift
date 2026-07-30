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
/// - 캘린더는 **할일 카드 왼쪽에만** 강제 표시(일정 카드는 일정 목록만) — 설정 미러를
///   건드리지 않고, 점 없이 이번 달만 정적으로(월 이동 셰브런 숨김) 그린다.
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
        // 캘린더는 **할일 카드에만**(일정 카드는 일정 목록만) — 둘 다 명시적 오버라이드로,
        // 사용자 설정 미러가 어떻든 목업 구성이 결정적이다. 목업 캘린더는 점 없이 이번 달만.
        // `isSample`은 정리(endSamples)용 마커 — 표시 결정과 분리해, 실사용 게시가 예시로
        // 오인될 여지를 없앤다.
        try? await startSchedule(
            events: Self.sampleEvents(now: now), now: now,
            showsCalendarOverride: false, isSample: true
        )
        try? await startReminder(
            listTitle: String(localized: "Sample"),
            reminders: Self.sampleReminders(),
            listColors: [:],
            now: now,
            showsCalendarOverride: true,
            isSample: true
        )
    }

    /// 오늘(종일 1 + 시간 2) + 내일(시간 3) 여섯 개 — 2열 레이아웃(열당 시간 이벤트 ~3개)을
    /// 왼쪽·오른쪽 모두 채워 실사용 밀도를 보여준다. 색은 애플 캘린더 팔레트 5종 — 여러
    /// 캘린더가 섞인 실사용처럼(외부 데이터 hex 예외 경로, 프리뷰 시드와 동일 관례).
    /// 오늘 시간 이벤트는 **다음 정시**부터 — "오후 3:47" 같은 어중간한 목업 시각 방지.
    /// (지난 일정 숨김 필터에도 안전 — 다음 정시는 항상 now 이후다.)
    static func sampleEvents(now: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        let tomorrowStart = todayStart.addingTimeInterval(86_400)
        let nextHour = calendar.dateInterval(of: .hour, for: now)?.end ?? now.addingTimeInterval(3_600)

        func timed(_ index: Int, start: Date, colorHex: String) -> CalendarEvent {
            CalendarEvent(
                id: "cue.sample.event.\(index)",
                title: String(localized: "Sample event \(index)"),
                startDate: start,
                endDate: start.addingTimeInterval(3_600),
                isAllDay: false,
                calendarColorHex: colorHex,
                isReadOnly: true
            )
        }

        return [
            CalendarEvent(
                id: "cue.sample.event.allday",
                title: String(localized: "Sample all-day event"),
                startDate: todayStart,
                endDate: tomorrowStart,
                isAllDay: true,
                calendarColorHex: "#FF3B30",
                isReadOnly: true
            ),
            timed(1, start: nextHour, colorHex: "#007AFF"),
            timed(2, start: nextHour.addingTimeInterval(7_200), colorHex: "#34C759"),
            timed(3, start: tomorrowStart.addingTimeInterval(9 * 3_600), colorHex: "#FF9500"),
            timed(4, start: tomorrowStart.addingTimeInterval(11.5 * 3_600), colorHex: "#AF52DE"),
            timed(5, start: tomorrowStart.addingTimeInterval(14 * 3_600), colorHex: "#32ADE6"),
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
