//
//  MonthWeekPacker.swift
//  cue / Shared
//

import Foundation

/// 한 주(7칸) 안에서 항목을 칸(lane)에 배치한 결과.
struct MonthWeekLayout: Equatable, Sendable {
    /// 일(day-of-month) → 칸별 항목. 길이는 언제나 `slots`이고, `nil`은 그 칸이 비었다는 뜻이다.
    /// 연속 일정이 지나가는 자리를 비워 두기 위해 `nil`을 그대로 들고 간다.
    let lanes: [Int: [WidgetCalendarItem?]]
    /// 일 → 칸이 모자라 못 그린 개수(`+N` 배지).
    let overflow: [Int: Int]

    static let empty = MonthWeekLayout(lanes: [:], overflow: [:])

    /// 그 날 셀에 그릴 칸 목록. 표시 월 밖 칸이면 빈 배열.
    func lanes(forDay day: Int) -> [WidgetCalendarItem?] { lanes[day] ?? [] }

    func overflow(forDay day: Int) -> Int { overflow[day] ?? 0 }
}

/// 월 캘린더 위젯의 **주 단위** 배치.
///
/// 날짜별로 따로 채우면 여러 날에 걸친 일정이 셀마다 다른 줄에 앉는다 — 8·9일에는 둘째 줄,
/// 10일부터는 첫째 줄에 그려져 하나의 일정이 세 토막으로 보인다(실기기에서 확인).
/// 그래서 배치 단위를 **하루가 아니라 한 주**로 올리고, 걸치는 일정에 주 전체에서 같은 칸을
/// 배정한다. 그 칸은 해당 일정이 지나가는 날 전부에서 예약되므로 가로로 이어져 보인다.
enum MonthWeekPacker {

    /// `days`는 그 주의 7칸(표시 월 밖은 `nil`), `itemsByDay`는 일 숫자로 색인한 항목들.
    static func pack(
        days: [Int?],
        itemsByDay: [Int: [WidgetCalendarItem]],
        slots: Int
    ) -> MonthWeekLayout {
        let present = days.compactMap { $0 }
        guard !present.isEmpty else { return .empty }

        let entries = self.entries(for: present, itemsByDay: itemsByDay).sorted(by: precedes)

        guard slots > 0 else {
            // 칸이 없으면 전부 `+N`으로. 빈 칸 배열은 그대로 둔다.
            var overflow: [Int: Int] = [:]
            for entry in entries {
                for day in entry.days { overflow[day, default: 0] += 1 }
            }
            return MonthWeekLayout(
                lanes: Dictionary(uniqueKeysWithValues: present.map { ($0, []) }),
                overflow: overflow
            )
        }

        var lanes: [Int: [WidgetCalendarItem?]] = Dictionary(
            uniqueKeysWithValues: present.map { ($0, [WidgetCalendarItem?](repeating: nil, count: slots)) }
        )
        var overflow: [Int: Int] = [:]

        for entry in entries {
            // 이 일정이 걸치는 **모든 날**에서 비어 있는 가장 낮은 칸을 찾는다.
            let lane = (0..<slots).first { index in
                entry.days.allSatisfy { lanes[$0]?[index] == nil }
            }
            guard let lane else {
                for day in entry.days { overflow[day, default: 0] += 1 }
                continue
            }
            for day in entry.days { lanes[day]?[lane] = entry.item }
        }

        return MonthWeekLayout(lanes: lanes, overflow: overflow)
    }

    // MARK: - 항목 모으기

    /// 같은 일정이 여러 날에 복제돼 들어오므로(데이터 소스가 걸치는 날마다 넣는다) id로 묶어
    /// "이 주에서 이 일정이 차지하는 날들"을 만든다.
    private struct Entry {
        let item: WidgetCalendarItem
        /// 이 주 안에서 이 일정이 나타나는 날들. 항상 오름차순.
        let days: [Int]
    }

    private static func entries(
        for present: [Int],
        itemsByDay: [Int: [WidgetCalendarItem]]
    ) -> [Entry] {
        var daysByID: [String: [Int]] = [:]
        var itemByID: [String: WidgetCalendarItem] = [:]

        for day in present.sorted() {
            for item in itemsByDay[day] ?? [] {
                if itemByID[item.id] == nil { itemByID[item.id] = item }
                daysByID[item.id, default: []].append(day)
            }
        }

        return daysByID.compactMap { id, days in
            itemByID[id].map { Entry(item: $0, days: days) }
        }
    }

    /// 배치 순서 — **걸치는 날이 많은 것부터**. 그다음 종류(종일 → 시간 → 미리알림),
    /// 시작 시각, 제목, id.
    ///
    /// 긴 일정을 먼저 놓는 게 핵심이다. 하루짜리부터 채우면 그것들이 위쪽 칸을 흩어 놓아
    /// 3일짜리 일정이 모든 날에서 동시에 비어 있는 칸을 못 찾고 통째로 `+N`으로 밀린다.
    /// 제목·id까지 비교하는 건 결정론 때문이다 — 순서가 흔들리면 위젯이 갱신마다 깜빡인다.
    private static func precedes(_ lhs: Entry, _ rhs: Entry) -> Bool {
        if lhs.days.count != rhs.days.count { return lhs.days.count > rhs.days.count }
        if lhs.item.kind != rhs.item.kind { return lhs.item.kind < rhs.item.kind }
        if lhs.item.start != rhs.item.start { return lhs.item.start < rhs.item.start }
        if lhs.item.title != rhs.item.title { return lhs.item.title < rhs.item.title }
        return lhs.item.id < rhs.item.id
    }
}

// MARK: - 가로 구간

/// 한 칸(lane) 안에서 가로로 이어지는 한 덩어리.
///
/// 연속 일정은 셀마다 따로 그리는 게 아니라 **여러 칸을 가로지르는 막대 하나**로 그린다.
/// 그래야 제목도 하나만 나오고, 3일짜리 일정이 세 번 반복되지 않는다.
struct MonthWeekRun: Identifiable, Equatable, Sendable {
    /// 시작 열(0 = 그 주의 첫 칸).
    let startColumn: Int
    /// 걸치는 열 수. 막대 폭은 `열 폭 × length`.
    let length: Int
    /// 그릴 항목. `nil`이면 그만큼 빈 자리를 둔다.
    let item: WidgetCalendarItem?

    var id: Int { startColumn }
    /// 여러 날에 걸친 막대인지 — 제목을 가운데로 보낼지 판단한다.
    var isSpanning: Bool { length > 1 }
}

extension MonthWeekPacker {

    /// 한 칸을 왼쪽부터 훑어 **같은 항목이 이어지는 구간**으로 묶는다.
    ///
    /// 인접한 두 열에 같은 일정이 앉아 있으면 하나의 막대다. 표시 월 밖 칸과 빈 칸은
    /// `item == nil`인 구간으로 묶여 자리만 차지한다.
    static func runs(week: [Int?], layout: MonthWeekLayout, lane: Int) -> [MonthWeekRun] {
        guard !week.isEmpty else { return [] }

        /// 그 열의 이 칸에 앉은 항목. 표시 월 밖이거나 비었으면 `nil`.
        func item(atColumn column: Int) -> WidgetCalendarItem? {
            guard let day = week[column] else { return nil }
            let lanes = layout.lanes(forDay: day)
            guard lanes.indices.contains(lane) else { return nil }
            return lanes[lane]
        }

        var runs: [MonthWeekRun] = []
        var start = 0

        for column in 1...week.count {
            // 마지막 열을 지나면 무조건 끊고, 그 전엔 항목이 바뀌는 지점에서 끊는다.
            let ended = column == week.count || item(atColumn: column)?.id != item(atColumn: start)?.id
            guard ended else { continue }
            runs.append(
                MonthWeekRun(startColumn: start, length: column - start, item: item(atColumn: start))
            )
            start = column
        }

        return runs
    }
}
