//
//  SmallCalendarWidgets.swift
//  cueLiveActivity
//
//  작은 위젯 두 종 — 이번 달 격자만 담는 "작은 캘린더", 오늘 날짜만 크게 담는 "오늘".
//

import SwiftUI
import WidgetKit

/// systemSmall 이번 달 격자 — 셀에 칩은 들어가지 않고 **점 마커**로 그날 무언가 있음을 알린다.
struct SmallCalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: CalendarWidgetKind.smallMonth,
            provider: CalendarWidgetProvider(range: .month(shift: nil))
        ) { entry in
            SmallCalendarEntryView(entry: entry)
        }
        .configurationDisplayName(widgetGalleryName("Small Calendar", requiresPremium: false))
        .description("")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

/// 오늘 날짜만 — 요일·월 한 줄 + 큰 숫자.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: CalendarWidgetKind.today,
            provider: CalendarWidgetProvider(range: .month(shift: nil))
        ) { entry in
            TodayEntryView(entry: entry)
        }
        .configurationDisplayName(widgetGalleryName("Today", requiresPremium: false))
        .description("")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

// MARK: - 작은 캘린더

/// systemSmall 격자 — 제목 헤더 + `CompactMonthGrid`.
struct SmallCalendarEntryView: View {
    let entry: CalendarWidgetEntry

    @Environment(\.colorScheme) private var colorScheme

    private var calendar: Calendar { .current }

    private var grid: MonthCalendarGrid {
        MonthCalendarGrid(now: entry.date, monthOffset: 0, calendar: calendar)
    }

    private var displayedMonth: Date {
        calendar.date(from: DateComponents(year: grid.year, month: grid.month, day: 1)) ?? entry.date
    }

    /// 표시 월의 일 숫자 → 그날 항목들.
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

    var body: some View {
        VStack(spacing: Spacing.zero) {
            // 헤더는 큰 위젯의 공통 바를 쓰지 않는다 — 셰브런 자리와 상하 여백이
            // small 높이에서 격자 한 주를 통째로 먹는다. 제목만 한 줄로 줄인다.
            HStack(spacing: Spacing.xs) {
                // 사이드 위젯 제목과 같은 크기 — 위젯 묶음에서 머리글이 한 가지로 읽힌다.
                Text(WidgetCalendarTheme.monthName(for: displayedMonth, calendar: calendar))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(WidgetCalendarTheme.yearName(for: displayedMonth, calendar: calendar))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: Spacing.zero)
            }
            .lineLimit(1)
            // 제목을 격자보다 더 들인다 — 카드 왼쪽 가장자리에 붙어 보이지 않게.
            .padding(.leading, Spacing.smd)
            .padding(.trailing, Spacing.xs)
            // 위젯 콘텐츠 마진을 껐기 때문에 위쪽 여백을 직접 준다 — 제목이 카드
            // 둥근 모서리에 붙으면 잘린 것처럼 답답해 보인다.
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xxs)

            if entry.snapshot.hasAccess {
                // 격자가 남는 높이를 **전부** 가져간다 — 위아래 여백을 크게 주면
                // 그만큼 캘린더가 작아진다(실기기에서 아래가 많이 남았다).
                //
                // `maxHeight: .infinity`로 남는 높이를 명시해 넘긴다. 격자 안쪽이
                // `GeometryReader`라 자기 고유 높이가 없어서, 이걸 안 주면 높이 0이 된다.
                CompactMonthGrid(grid: grid, itemsByDay: itemsByDay, holidays: holidays)
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, Spacing.xxs)
                    // 마지막 주가 카드 바닥에 닿으면 격자가 잘린 것처럼 보인다.
                    .padding(.bottom, Spacing.sm)
            } else {
                WidgetAccessPrompt()
            }
        }
        .dynamicTypeSize(.xSmall)
        .calendarWidgetBackground(colorScheme)
    }
}

// MARK: - 오늘

/// 요일·월 한 줄 + 큰 날짜 숫자. 목록은 붙이지 않는다 — 이 위젯의 정보는 "오늘이 며칠인가" 하나다.
struct TodayEntryView: View {
    let entry: CalendarWidgetEntry

    @Environment(\.colorScheme) private var colorScheme

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Text(WidgetCalendarTheme.weekdayName(for: entry.date, calendar: calendar))
                    .foregroundStyle(.primary)
                Text(WidgetCalendarTheme.monthName(for: entry.date, calendar: calendar))
                    .foregroundStyle(.secondary)
            }
            // 큰 숫자와 나란히 서는 줄이라 본문보다 굵게 — 숫자에 눌려 사라지지 않게.
            .font(.headline)
            .lineLimit(1)
            // 로케일에 따라 요일+월이 길어질 수 있다("Wednesday September"). 줄이 넘치면
            // 두 줄로 접히며 아래 숫자를 밀어내므로, 폭 안에서 줄여 한 줄을 지킨다.
            .minimumScaleFactor(0.7)

            Text("\(calendar.component(.day, from: entry.date))")
                // 이 위젯의 유일한 정보다 — 램프에서 가장 큰 스타일로 그린다.
                .font(.system(.largeTitle, design: .rounded, weight: .light))
                // largeTitle로도 스크린샷만큼 크지 않다. 위젯 높이의 절반을 채우도록
                // 배율로 키운다 — `.system(size:)` 고정 크기는 쓰지 않는다.
                .scaleEffect(Self.dayNumberScale)
                .monospacedDigit()
                .foregroundStyle(.primary)
                // 배율로 커진 만큼 레이아웃 높이는 그대로라 아래위가 붙는다 — 커진 몫만큼
                // 자리를 비워 준다.
                .padding(.vertical, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dynamicTypeSize(.xSmall)
        .calendarWidgetBackground(colorScheme)
    }

    /// 날짜 숫자 배율 — largeTitle(34pt) × 1.8 ≈ 61pt로, small 위젯(≈158pt) 높이의 40%쯤.
    private static let dayNumberScale: CGFloat = 1.8
}
