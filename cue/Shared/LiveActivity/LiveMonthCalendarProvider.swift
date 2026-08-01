//
//  LiveMonthCalendarProvider.swift
//  cue / Shared
//
//  LA 잠금화면 월간 캘린더(MonthCalendarView)가 그릴 한 달치 — 날짜별 일정 점 + 공휴일.
//  앱·익스텐션 양쪽에 컴파일되지만(공유 인텐트가 참조) EKEventStore 조회는 **앱 프로세스에서만**
//  실행된다 — 발행(ActivityKitLiveActivityService)과 월 이동 인텐트(ShiftCalendarMonthIntent)가
//  이 provider를 호출한다. EventKit 경계 글루라 RED 면제.
//
//  LA 위젯은 렌더 시점에 EventKit을 읽을 수 없으므로(ContentState만으로 그린다) 공휴일도
//  점과 똑같이 **여기서 미리 뽑아 ContentState에 실어 보낸다**.
//

import EventKit
import Foundation
import os

enum LiveMonthCalendarProvider {
    /// [진단용 임시] 점이 비는 원인 격리 로그 — 원인 확정 후 제거한다.
    /// 듀얼 타깃 파일이라 앱 전용 AppLogger 대신 로컬 Logger를 쓴다.
    private static let log = Logger(subsystem: "azhy.cue", category: "monthDots")
    /// 하루 최대 3점 — 초과분은 안 그린다. 점이 늘어 ContentState가 커지면 리스트 아이템 수를
    /// 적응형 fitter가 알아서 줄여 4KB 한도를 지킨다.
    static let maxDotsPerDay = 3

    /// 표시 월(`now + monthOffset`)의 일정 점과 공휴일. 캘린더 권한이 없으면 빈 값.
    ///
    /// 숨긴 캘린더는 App Group의 `hiddenCalendarIDs`로 거른다 — 점에서도 공휴일에서도 뺀다.
    /// 사용자가 공휴일 캘린더를 숨겼다면 그 날짜를 빨갛게 칠할 이유도 없다.
    ///
    /// **오늘을 빼는 건 점뿐이다**(오늘은 밑줄로 표시). 공휴일 색까지 빼면 오늘이 공휴일일 때
    /// 그날만 검게 남는다.
    static func month(
        monthOffset: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> LiveMonthCalendar {
        let status = EKEventStore.authorizationStatus(for: .event)
        let processName = ProcessInfo.processInfo.processName
        guard status == .fullAccess || status == .writeOnly else {
            log.error("[진단] 권한 미달로 점 없음 — status=\(status.rawValue) process=\(processName)")
            return .empty
        }

        let base = calendar.startOfDay(for: now)
        guard let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: base),
              let month = calendar.dateInterval(of: .month, for: monthDate) else { return .empty }

        let store = EKEventStore()
        let predicate = store.predicateForEvents(withStart: month.start, end: month.end, calendars: nil)
        let hidden = hiddenCalendarIDs()
        let todayStart = calendar.startOfDay(for: now)

        // 시작 시간순으로 정렬해 하루 안 점 순서를 앱 목록과 맞춘다.
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        var order: [Int] = []
        var byDay: [Int: [String]] = [:]
        var holidays = Set<Int>()
        for event in events {
            guard !hidden.contains(event.calendar.calendarIdentifier) else { continue }

            if HolidayEventPolicy.isHoliday(
                isSubscribed: event.calendar.isSubscribed,
                allowsContentModifications: event.calendar.allowsContentModifications,
                isAllDay: event.isAllDay
            ) {
                // 여러 날짜짜리 공휴일(연휴가 이벤트 하나로 오는 경우)도 걸치는 날을 모두 칠한다.
                holidays.formUnion(days(from: event, within: month, calendar: calendar))
            }

            let dayStart = calendar.startOfDay(for: event.startDate)
            guard dayStart >= month.start, dayStart < month.end, dayStart != todayStart else { continue }
            let day = calendar.component(.day, from: dayStart)
            if byDay[day] == nil { order.append(day) }
            byDay[day, default: []].append(hex(from: event.calendar.cgColor) ?? "")
        }
        log.info("""
        [진단] offset=\(monthOffset) process=\(processName) status=\(status.rawValue) \
        조회이벤트=\(events.count) 숨김캘린더=\(hidden.count) 점날짜=\(order.count) \
        공휴일=\(holidays.count)
        """)
        return LiveMonthCalendar(
            dots: order.sorted().map {
                LiveMonthDot(day: $0, colorHexes: Array(byDay[$0, default: []].prefix(maxDotsPerDay)))
            },
            holidays: holidays.sorted()
        )
    }

    /// 이벤트가 걸치는 **표시 월 안의** 일 숫자들.
    ///
    /// 종일 이벤트의 `endDate`는 마지막 날 안쪽을 가리키므로 그 날짜까지 포함한다.
    private static func days(
        from event: EKEvent,
        within month: DateInterval,
        calendar: Calendar
    ) -> [Int] {
        var result: [Int] = []
        var cursor = calendar.startOfDay(for: event.startDate)
        let last = calendar.startOfDay(for: event.endDate)
        while cursor <= last {
            if cursor >= month.start, cursor < month.end {
                result.append(calendar.component(.day, from: cursor))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private static func hiddenCalendarIDs() -> Set<String> {
        Set(SharedAppGroup.defaults.stringArray(forKey: SharedAppGroup.Keys.hiddenCalendarIDs) ?? [])
    }

    /// `CGColor` → "#RRGGBB". `EventMapper.hex`와 동일 규칙(위젯 타깃엔 EventMapper가 없어 복제).
    private static func hex(from cgColor: CGColor?) -> String? {
        guard let components = cgColor?.components, components.count >= 3 else { return nil }
        let r = Int(round(max(0, min(1, components[0])) * 255))
        let g = Int(round(max(0, min(1, components[1])) * 255))
        let b = Int(round(max(0, min(1, components[2])) * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
