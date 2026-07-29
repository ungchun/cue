//
//  WidgetCalendarSample.swift
//  cue / Shared
//

import Foundation

/// 위젯 갤러리 미리보기에 쓰는 **가짜 일정**.
///
/// 갤러리에서는 EventKit을 건드리지 않는다 — 권한 프롬프트가 뜨면 위젯을 고르다 말고
/// 시스템 다이얼로그를 만나게 되고, 아직 권한을 안 준 사람에게는 빈 격자만 보인다.
/// 그렇다고 빈 채로 두면 "이 위젯이 뭘 보여주는지"를 알 수 없어 고를 수가 없다.
///
/// 그래서 실제 데이터처럼 보이는 표본을 그린다. 날짜는 **오늘 기준 상대값**이라
/// 언제 열어도 자연스럽고, 제목은 사용자의 실제 일정과 헷갈리지 않게 일반적인 단어로 둔다.
enum WidgetCalendarSample {

    /// 갤러리 미리보기용 스냅샷 — `from`~`to` 구간을 표본으로 채운다.
    static func snapshot(
        from: Date,
        to: Date,
        calendar: Calendar = .current
    ) -> WidgetCalendarSnapshot {
        var itemsByDay: [Date: [WidgetCalendarItem]] = [:]
        var day = calendar.startOfDay(for: from)

        var index = 0
        while day < to {
            let items = self.items(on: day, index: index, calendar: calendar)
            if !items.isEmpty { itemsByDay[day] = items }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            index += 1
        }

        // 권한이 있는 것처럼 둔다 — 미리보기에서 안내 문구가 뜨면 정작 위젯 모습을 못 본다.
        return WidgetCalendarSnapshot(itemsByDay: itemsByDay, hasAccess: true)
    }

    // MARK: - 표본

    /// 하루치 표본. 요일마다 다른 조합을 주어 격자가 단조롭지 않게 한다.
    ///
    /// 월 위젯은 한 셀에 두세 개만 들어가므로 하루 3개면 충분하고, 시간표 위젯은
    /// 그보다 성기게 보이지만 시각이 흩어져 있어 하루의 리듬이 읽힌다.
    private static func items(
        on day: Date,
        index: Int,
        calendar: Calendar
    ) -> [WidgetCalendarItem] {
        // 주말은 비워 둔다 — 모든 날이 꽉 차 있으면 오히려 가짜처럼 보인다.
        let weekday = calendar.component(.weekday, from: day)
        guard weekday != 1, weekday != 7 else {
            return index % 3 == 0 ? [item(.weekendPlan, on: day, calendar: calendar)] : []
        }

        switch index % 4 {
        case 0:
            return [
                item(.standup, on: day, calendar: calendar),
                item(.review, on: day, calendar: calendar),
                item(.workout, on: day, calendar: calendar)
            ]
        case 1:
            return [
                item(.standup, on: day, calendar: calendar),
                item(.lunch, on: day, calendar: calendar)
            ]
        case 2:
            return [
                item(.standup, on: day, calendar: calendar),
                item(.oneOnOne, on: day, calendar: calendar),
                item(.workout, on: day, calendar: calendar)
            ]
        default:
            return [
                item(.standup, on: day, calendar: calendar),
                item(.review, on: day, calendar: calendar)
            ]
        }
    }

    /// 표본 한 종류 — 제목·시각·색·종류를 묶어 둔다.
    ///
    /// `title`은 **번역 키**다. 문자열 리터럴로 두는 게 핵심 — `String.LocalizationValue`나
    /// `String(localized:)`를 쓰면 Xcode가 이 파일을 스캔해 **앱 쪽 `.xcstrings`에도** 키를
    /// 자동 수집한다. 갤러리 미리보기용 가짜 일정이 앱 번역 대상에 섞이면 안 된다
    /// (이 파일은 앱·위젯 두 타깃에 함께 들어간다).
    private struct Template {
        let title: String
        let hour: Int
        let minute: Int
        /// 분 단위 길이. `0`이면 미리알림(길이 없음).
        let minutes: Int
        let colorHex: String

        static let standup = Template(
            title: "Standup", hour: 9, minute: 30, minutes: 30, colorHex: "#4A90D9"
        )
        static let review = Template(
            title: "Design review", hour: 14, minute: 0, minutes: 60, colorHex: "#9B59B6"
        )
        static let oneOnOne = Template(
            title: "1:1", hour: 11, minute: 0, minutes: 30, colorHex: "#2E9E6B"
        )
        static let lunch = Template(
            title: "Lunch with team", hour: 12, minute: 0, minutes: 60, colorHex: "#E67E22"
        )
        static let workout = Template(
            title: "Workout", hour: 19, minute: 0, minutes: 0, colorHex: "#D0453B"
        )
        static let weekendPlan = Template(
            title: "Coffee", hour: 15, minute: 0, minutes: 0, colorHex: "#D0453B"
        )
    }

    private static func item(
        _ template: Template,
        on day: Date,
        calendar: Calendar
    ) -> WidgetCalendarItem {
        let start = calendar.date(
            bySettingHour: template.hour, minute: template.minute, second: 0, of: day
        ) ?? day
        let end = start.addingTimeInterval(TimeInterval(template.minutes * 60))
        let isReminder = template.minutes == 0

        return WidgetCalendarItem(
            // 날짜를 붙여 유일하게 만든다 — 같은 표본이 여러 날에 반복되므로
            // 제목만으로는 `ForEach`가 id 충돌로 하나만 그린다.
            id: "sample-\(template.title)-\(start.timeIntervalSince1970)",
            // 번역은 **런타임 조회**로 가져온다. 컴파일 타임 매크로(`String(localized:)`)를
            // 쓰면 앱 `.xcstrings`까지 키가 수집되므로(→ `Template.title`), 그 경로를 피한다.
            title: Bundle.main.localizedString(forKey: template.title, value: nil, table: nil),
            start: start,
            end: end,
            kind: isReminder ? .reminder : .timedEvent,
            colorHex: template.colorHex,
            isHighPriority: false
        )
    }
}
