//
//  SideListCalendarWidgets.swift
//  cueLiveActivity
//
//  캘린더 + 목록 위젯 두 종 — 왼쪽은 이번 달 격자, 오른쪽은 다가오는 일정/할일.
//  본문은 같고 목록에 담는 종류만 다르다.
//

import SwiftUI
import WidgetKit

/// 이번 달 격자 + 다가오는 **일정** 목록.
struct CalendarEventListWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: CalendarWidgetKind.eventList,
            provider: CalendarWidgetProvider(range: .upcoming)
        ) { entry in
            SideListEntryView(entry: entry, mode: .events)
        }
        .configurationDisplayName(widgetGalleryName("Today's Events", requiresPremium: false))
        .description("")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

/// 이번 달 격자 + 다가오는 **할일** 목록.
struct CalendarReminderListWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: CalendarWidgetKind.reminderList,
            provider: CalendarWidgetProvider(range: .upcoming)
        ) { entry in
            SideListEntryView(entry: entry, mode: .reminders)
        }
        .configurationDisplayName(widgetGalleryName("Today's Reminders", requiresPremium: false))
        .description("")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

/// 두 사이드 리스트 위젯이 공유하는 본문.
struct SideListEntryView: View {

    /// 오른쪽 목록에 무엇을 담는지 — 위젯 두 종을 가르는 유일한 축.
    enum Mode {
        case events
        case reminders

        var kinds: Set<WidgetCalendarItem.Kind> {
            switch self {
            case .events: return [.allDayEvent, .timedEvent]
            case .reminders: return [.reminder]
            }
        }

        var emptyText: LocalizedStringKey {
            switch self {
            case .events: return "No upcoming events"
            case .reminders: return "No upcoming reminders"
            }
        }
    }

    let entry: CalendarWidgetEntry
    let mode: Mode

    @Environment(\.colorScheme) private var colorScheme

    private var calendar: Calendar { .current }

    private var grid: MonthCalendarGrid {
        MonthCalendarGrid(now: entry.date, monthOffset: 0, calendar: calendar)
    }

    private var displayedMonth: Date {
        calendar.date(from: DateComponents(year: grid.year, month: grid.month, day: 1)) ?? entry.date
    }

    /// 격자에 그릴 표시 월의 항목 — **일 숫자 키**로 눕힌다(월 위젯과 같은 규칙).
    private var itemsByDay: [Int: [WidgetCalendarItem]] {
        var result: [Int: [WidgetCalendarItem]] = [:]
        for (day, items) in entry.snapshot.itemsByDay {
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            guard parts.year == grid.year, parts.month == grid.month, let number = parts.day else { continue }
            result[number] = items
        }
        return result
    }

    private var holidays: Set<Int> {
        Set(itemsByDay.filter { $0.value.contains(where: \.isHoliday) }.keys)
    }

    /// 오른쪽 목록에 세울 항목 — 지금 이후로 다가오는 순.
    private var listItems: [WidgetCalendarItem] {
        UpcomingItemPicker.items(
            from: entry.snapshot,
            kinds: mode.kinds,
            now: entry.date,
            limit: Self.listLimit,
            calendar: calendar
        )
    }

    /// 목록에 세울 최대 개수 — 넷(제품 요구). 넷이 들어가도록 간격을 예산이 조절한다
    /// (→ `UpcomingListMetrics`).
    private static let listLimit = UpcomingListMetrics.rowCount

    var body: some View {
        // 루트에서만 `GeometryReader`를 쓴다 — 여기서는 시스템이 위젯 크기를 확정해
        // 주므로 잰 값이 정확하다. (`VStack` 안에 넣으면 자기 높이를 정하지 못해
        // 자식이 넘쳐도 막지 못한다 — 그게 앞서 카드 밖으로 삐져나온 원인이었다.)
        GeometryReader { geometry in
            let width = geometry.size.width

            if entry.snapshot.hasAccess {
                // 선을 긋지 않는다 — 헤더 아래 가로선도, 격자와 목록 사이 세로선도.
                // 여백만으로 두 영역이 갈린다(레퍼런스와 동일). 이 크기에서 선은 격자
                // 숫자만큼의 잉크를 써서 정작 날짜보다 선이 먼저 읽힌다.
                HStack(alignment: .top, spacing: Spacing.zero) {
                    // 왼쪽 — 월·연도 제목과 격자가 **한 덩어리**다. 제목이 위젯 전체가 아니라
                    // 캘린더 위에 얹혀야 격자의 머리글로 읽힌다(레퍼런스와 동일).
                    VStack(alignment: .leading, spacing: Spacing.zero) {
                        monthTitle
                        // 큰 위젯의 `MonthWidgetView`는 쓸 수 없다. 셀 폭이 24pt라 제목 칩이
                        // "일ㅈ"으로 잘렸고, 행 높이 예산이 위젯 높이를 넘겨 마지막 주가
                        // 밖으로 밀려났다 — 작은 캘린더와 같은 격자를 쓴다.
                        CompactMonthGrid(
                            grid: grid,
                            itemsByDay: itemsByDay,
                            holidays: holidays
                        )
                        // 제목 아래 남는 높이를 전부 준다 — 격자 안쪽이 `GeometryReader`라
                        // 자기 고유 높이가 없어서, 이걸 안 주면 높이 0이 된다.
                        .frame(maxHeight: .infinity)
                    }
                    // 여백을 **폭 안쪽에** 준다 — 바깥에 주면 그만큼 두 영역의 합이
                    // 위젯보다 커져 반씩이 아니게 되고 오른쪽이 밖으로 밀린다.
                    .padding(.leading, Spacing.sm)
                    .padding(.trailing, Spacing.xxs)
                    .frame(width: width * Self.gridWidthShare)
                    WidgetItemListView(
                        items: listItems,
                        emptyText: mode.emptyText,
                        calendar: calendar
                    )
                    // 왼쪽 격자와 붙어 보이지 않게 띄운다 — 두 영역을 가르는 선이 없어서
                    // (레퍼런스와 동일) 이 여백이 유일한 경계다.
                    .padding(.leading, Spacing.sm)
                    .padding(.trailing, Spacing.xxs)
                    .frame(width: width * (1 - Self.gridWidthShare))
                }
                // 위아래 여백은 최소로 — 격자와 목록이 카드를 가득 채워야 한다.
                // 크게 주면 그만큼 격자가 쪼그라든다(실기기에서 그랬다).
                .padding(.vertical, Spacing.xs)
                // 잰 크기를 그대로 채운다 — 자식이 넘쳐도 카드 밖으로 나가지 않는다.
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            } else {
                WidgetAccessPrompt()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .dynamicTypeSize(.xSmall)
        .calendarWidgetBackground(colorScheme)
    }

    /// 왼쪽 격자가 가져가는 폭 비율 — 캘린더와 목록이 **정확히 반씩**.
    private static let gridWidthShare: CGFloat = 0.5

    /// 격자 위 왼쪽에 앉는 "8월 2026년" — 월은 굵게, 연도는 흐리게.
    private var monthTitle: some View {
        // 월과 연도를 붙여 놓으면 "8월2026년"으로 읽힌다 — 월 위젯 헤더와 같은 값으로 띄운다.
        HStack(alignment: .firstTextBaseline, spacing: WidgetCalendarTheme.headerTitleGap) {
            // 월이 이 줄의 머리다 — 연도보다 한 단계 크게 잡아 먼저 읽히게 한다.
            Text(WidgetCalendarTheme.monthName(for: displayedMonth, calendar: calendar))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
            Text(WidgetCalendarTheme.yearName(for: displayedMonth, calendar: calendar))
                // 월(`.footnote`)보다 한 단계 작게 — 이 위젯은 폭이 절반뿐이라
                // 제목이 커지면 격자가 쓸 자리를 그만큼 잃는다.
                .font(.caption2)
                .foregroundStyle(WidgetCalendarTheme.headerYear)
        }
        .lineLimit(1)
        // 제목을 격자 첫 열(일요일)보다 더 들인다 — 정확히 맞추면 카드 왼쪽
        // 가장자리에 붙어 보인다.
        .padding(.leading, Spacing.sm)
        // 요일 줄이 자기 글자 크기만큼만 자리를 잡으므로(→ `CompactMonthGrid`)
        // 여기 값이 곧 제목과 요일 줄 사이의 전부다. 음수까지 주면 겹친다.
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.xs)
    }

}
