//
//  UpcomingItemPicker.swift
//  cue / Shared
//

import Foundation

/// 사이드 리스트 위젯이 그릴 **다가오는 항목**을 고른다.
///
/// 뷰가 아니라 여기 두는 이유: "무엇을 보여줄지"는 순수 규칙이고, 화면 없이 검증할 수
/// 있어야 한다. 스냅샷은 날짜별 사전이라 그대로는 시간순 목록이 아니다 — 걸치는 일정이
/// 날마다 복제돼 있고(→ `WidgetCalendarDataSource`), 정렬도 날짜 키 단위다.
enum UpcomingItemPicker {

    /// `kind`로 일정/할일을 가른 뒤, 다가오는 순서대로 `limit`개.
    ///
    /// 오늘 것이 없으면 자연히 내일·모레 것이 올라온다 — 리스트가 비어 위젯이 텅 비는
    /// 일을 막는다.
    ///
    /// **지나간 것을 자르는 기준이 종류마다 다르다:**
    /// - 시간 일정: 끝나면 뺀다. 오전에 끝난 회의는 지나간 사실이다.
    /// - 종일 일정: 그날 전체가 유효하다.
    /// - 할일: **오늘 마감이면 시각이 지나도 남긴다.** 오전 9시 마감이 오후 2시에도
    ///   여전히 해야 할 일이라서다. 하루가 지나야 사라진다.
    ///
    /// - Parameters:
    ///   - kinds: 담을 종류. 일정 위젯은 종일+시간 일정, 할일 위젯은 미리알림.
    ///   - now: 기준 시각. 이 시각 **이후**에 끝나는 항목만 남긴다.
    static func items(
        from snapshot: WidgetCalendarSnapshot,
        kinds: Set<WidgetCalendarItem.Kind>,
        now: Date,
        limit: Int,
        calendar: Calendar = .current
    ) -> [WidgetCalendarItem] {
        let today = calendar.startOfDay(for: now)
        var seen = Set<String>()
        var result: [WidgetCalendarItem] = []

        // 날짜 키를 시간순으로 훑는다 — 걸치는 일정의 복제본은 첫 등장만 남긴다(`seen`).
        for day in snapshot.itemsByDay.keys.sorted() where day >= today {
            for item in snapshot.itemsByDay[day, default: []].sorted(by: isEarlier) {
                guard kinds.contains(item.kind) else { continue }
                // 완료한 할일은 뺀다 — 이 목록은 "아직 할 것"을 세우는 자리다.
                //
                // 캘린더 격자의 점은 그대로 둔다(→ `WidgetCalendarDataSource.showsReminder`).
                // 거기는 "그날 무엇이 있었나"를 보여주는 자리라 규칙이 다르다.
                if item.isCompleted { continue }
                // 종일 일정은 **담긴 날짜 키**로 판단한다 — 이 루프가 이미 오늘 이후만
                // 훑으므로 그 자체로 유효하다.
                //
                // `item.start`로 재면 안 된다: 스냅샷은 걸치는 일정을 날마다 복제해 넣는데
                // (→ `WidgetCalendarDataSource`) 복제본도 **원본 시작일**을 그대로 들고 있다.
                // 어제 시작한 3박4일 여행이 오늘 키에 들어 있어도 시작일이 어제라 잘려나가,
                // 여행 둘째 날부터 목록에서 사라졌다.
                //
                // 할일은 **날짜로** 잰다 — 오전 9시 마감이 오후 2시에도 여전히 해야 할
                // 일이다. 시각으로 자르면 그날 밀린 할 일이 위젯에서 사라져, 정작
                // "아직 안 한 것"을 볼 수 없다. 하루가 지나면 위 루프가 걸러낸다.
                //
                // 시간 일정은 `end`로 잰다 — 오늘 오전에 끝난 회의는 지나간 사실이라
                // 오후에 보일 이유가 없다. 종일 일정은 그날 전체가 유효하다.
                if item.kind == .timedEvent, item.end < now { continue }
                guard seen.insert(item.id).inserted else { continue }
                result.append(item)
                if result.count == limit { return result }
            }
        }
        return result
    }

    /// 하루 안에서의 순서 — 시각이 빠른 것부터, 같으면 종일 → 시간 → 할일 순.
    private static func isEarlier(_ lhs: WidgetCalendarItem, _ rhs: WidgetCalendarItem) -> Bool {
        if lhs.start != rhs.start { return lhs.start < rhs.start }
        return lhs.kind < rhs.kind
    }
}
