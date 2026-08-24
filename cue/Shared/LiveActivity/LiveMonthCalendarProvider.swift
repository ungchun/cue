//
//  LiveMonthCalendarProvider.swift
//  cue / Shared
//
//  LA 잠금화면 월간 캘린더(MonthCalendarView)가 그릴 한 달치 — 날짜별 점 + 공휴일.
//  앱·익스텐션 양쪽에 컴파일되지만(공유 인텐트가 참조) EventKit 조회는 **앱 프로세스에서만**
//  실행된다 — 발행(ActivityKitLiveActivityService)과 월 이동 인텐트(ShiftCalendarMonthIntent)가
//  이 provider를 호출한다. EventKit 경계 글루라 RED 면제.
//
//  LA 위젯은 렌더 시점에 EventKit을 읽을 수 없으므로(ContentState만으로 그린다) 공휴일도
//  점과 똑같이 **여기서 미리 뽑아 ContentState에 실어 보낸다**.
//

import Foundation
import os

enum LiveMonthCalendarProvider {
    /// [진단용 임시] 점이 비는 원인 격리 로그 — 원인 확정 후 제거한다.
    /// 듀얼 타깃 파일이라 앱 전용 AppLogger 대신 로컬 Logger를 쓴다.
    private static let log = Logger(subsystem: "azhy.cue", category: "monthDots")

    /// 표시 월(`now + monthOffset`)의 점과 공휴일. 캘린더·미리알림 권한이 둘 다 없으면 빈 값.
    ///
    /// 조회는 홈 위젯과 **같은 경로**(`WidgetCalendarDataSource`)를 쓴다 — 일정과 할일을
    /// 함께 담고, 숨긴 캘린더·숨긴 할일 목록을 거르고, 여러 날 걸친 일정을 걸치는 날마다
    /// 복제하는 규칙이 전부 그쪽 하나에 있다. 예전엔 여기서 `EKEvent`만 따로 조회해,
    /// 할일뿐인 날이 LA에서만 빈 날로 보였다.
    ///
    /// **오늘을 빼는 건 점뿐이다**(오늘은 밑줄로 표시). 공휴일 색까지 빼면 오늘이 공휴일일 때
    /// 그날만 검게 남는다.
    static func month(
        monthOffset: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> LiveMonthCalendar {
        let base = calendar.startOfDay(for: now)
        guard let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: base),
              let month = calendar.dateInterval(of: .month, for: monthDate) else { return .empty }

        let snapshot = WidgetCalendarDataSource.snapshot(
            from: month.start, to: month.end, calendar: calendar
        )
        guard snapshot.hasAccess else {
            log.error("[진단] 권한 미달로 점 없음 — process=\(ProcessInfo.processInfo.processName)")
            return .empty
        }

        var dots: [LiveMonthDot] = []
        var holidays: [Int] = []
        // 일 숫자로만 식별하는 자료구조라(→ `LiveMonthDot`) 날짜 순으로 훑어 순서를 고정한다.
        for (day, items) in snapshot.itemsByDay.sorted(by: { $0.key < $1.key }) {
            let number = calendar.component(.day, from: day)
            if items.contains(where: \.isHoliday) { holidays.append(number) }

            guard day != base else { continue }
            // 점 고르기는 홈 위젯 격자와 같은 규칙(`MonthDotColors`) — 갈리면 같은 날이
            // 두 화면에서 다른 점으로 보인다. 색 없는 항목은 `""`로 실어 보내 뷰가
            // 본문 색으로 폴백하게 둔다(`Color(hex:)`가 nil을 돌려준다).
            let colorHexes = MonthDotColors.colors(for: items).map { $0 ?? "" }
            guard !colorHexes.isEmpty else { continue }
            dots.append(LiveMonthDot(day: number, colorHexes: colorHexes))
        }

        log.info("""
        [진단] offset=\(monthOffset) process=\(ProcessInfo.processInfo.processName) \
        점날짜=\(dots.count) 공휴일=\(holidays.count)
        """)
        return LiveMonthCalendar(dots: dots, holidays: holidays)
    }
}
