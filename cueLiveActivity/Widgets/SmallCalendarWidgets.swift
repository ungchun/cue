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
            // 월과 연도를 붙여 놓으면 "8월2026년"으로 읽힌다 — 월 위젯 헤더와 같은 값으로 띄운다.
            HStack(alignment: .firstTextBaseline, spacing: WidgetCalendarTheme.headerTitleGap) {
                // 사이드 위젯 제목과 같은 크기 — 위젯 묶음에서 머리글이 한 가지로 읽힌다.
                Text(WidgetCalendarTheme.monthName(for: displayedMonth, calendar: calendar))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(WidgetCalendarTheme.yearName(for: displayedMonth, calendar: calendar))
                    // 사이드 위젯 제목과 같은 규칙 — 월보다 두 단계 작게.
                    .font(.caption2)
                    .foregroundStyle(WidgetCalendarTheme.headerYear)
                Spacer(minLength: Spacing.zero)
            }
            .lineLimit(1)
            // 제목을 격자보다 더 들인다 — 카드 왼쪽 가장자리에 붙어 보이지 않게.
            .padding(.leading, Spacing.smd)
            .padding(.trailing, Spacing.xs)
            // 위젯 콘텐츠 마진을 껐기 때문에 위쪽 여백을 직접 준다 — 제목이 카드
            // 둥근 모서리에 붙으면 잘린 것처럼 답답해 보인다.
            .padding(.top, Spacing.smd)
            // 요일 줄이 자기 글자 크기만큼만 자리를 잡으므로(→ `CompactMonthGrid`)
            // 여기 값이 곧 제목과 요일 줄 사이의 전부다. 음수까지 주면 겹친다.
            .padding(.bottom, Spacing.xs)

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
///
/// 배치는 기본 캘린더의 "날짜" 위젯을 따른다 — 가운데 정렬, 요일 줄 바로 아래 큰 숫자.
/// 다만 월(`8월`)을 함께 둔다: 기본 캘린더는 앱 아이콘에도 날짜가 있어 월을 생략해도
/// 맥락이 남지만, 이 위젯은 그렇지 않다.
///
/// 날짜 숫자는 고정 크기(`.system(size:)`)를 쓴다 — 메모·집중 LA의 큰 헤드라인과 같은
/// 예외다. 카드의 절반을 채우는 게 목적이라 텍스트 스타일 램프의 최대값(`largeTitle` 34pt)
/// 으로는 모자라고, 위젯은 `dynamicTypeSize(.xSmall)`로 렌더를 고정하므로 접근성 글자
/// 크기를 깨뜨리지도 않는다(→ `docs/design-system.md`의 금지 조항이 겨냥하는 상황이 아니다).
struct TodayEntryView: View {
    let entry: CalendarWidgetEntry

    @Environment(\.colorScheme) private var colorScheme

    private var calendar: Calendar { .current }

    var body: some View {
        // 요일 줄과 숫자를 **거의 붙인다** — 기본 캘린더 "날짜" 위젯과 같은 리듬이다.
        //
        // 음수 간격인 건 글자 줄 상자에 위아래 여백이 이미 들어 있어서다. 0으로 두면
        // 그 여백만큼 떠서 두 줄이 따로 놀고, 위젯의 중심이 흐려진다.
        VStack(spacing: -Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(WidgetCalendarTheme.weekdayName(for: entry.date, calendar: calendar))
                    .foregroundStyle(.primary)
                Text(WidgetCalendarTheme.monthName(for: entry.date, calendar: calendar))
                    // 헤더의 연도와 같은 농도 — 요일보다 물러나되 회색으로 죽지 않는다.
                    .foregroundStyle(WidgetCalendarTheme.headerYear)
            }
            // 큰 숫자와 나란히 서는 줄이라 굵게 — 숫자에 눌려 사라지지 않게.
            .font(.title3.weight(.semibold))
            .lineLimit(1)
            // 로케일에 따라 요일+월이 길어질 수 있다("Wednesday September"). 줄이 넘치면
            // 두 줄로 접히며 아래 숫자를 밀어내므로, 폭 안에서 줄여 한 줄을 지킨다.
            .minimumScaleFactor(0.6)

            Text("\(calendar.component(.day, from: entry.date))")
                // 이 위젯의 유일한 정보다 — 카드의 절반을 채우도록 크게 그린다.
                //
                // 텍스트 스타일 램프의 가장 큰 값(`largeTitle` 34pt)으로도 이 크기가
                // 안 나온다. 위젯은 사용자 글자 크기를 따르지 않고(`dynamicTypeSize`를
                // 고정한다) 이 숫자가 곧 위젯 자체라, 여기서는 크기를 직접 잡는다.
                .font(.system(size: Self.dayNumberSize, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                // 폭이 좁은 기기에서 두 자리 숫자가 잘리지 않게 — 크기를 직접 잡았으므로
                // 넘칠 때 줄여줄 안전망이 필요하다.
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dynamicTypeSize(.xSmall)
        .calendarWidgetBackground(colorScheme)
    }

    /// 날짜 숫자 크기 — small 위젯(가장 좁은 기기 141pt)에서도 카드의 절반쯤을 차지한다.
    ///
    /// 간격이 아니라 **레이아웃 치수**라 `Spacing` 토큰을 쓰지 않는다.
    private static let dayNumberSize: CGFloat = 72
}
