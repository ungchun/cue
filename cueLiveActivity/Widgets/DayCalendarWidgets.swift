//
//  DayCalendarWidgets.swift
//  cueLiveActivity
//
//  시간표 위젯 두 종 — 3일 위젯과 1일 위젯. 본문(`DayTimelineView`)은 같고
//  열 수와 날짜 머리글만 다르다.
//

import SwiftUI
import WidgetKit

/// 오늘부터 3일치 시간표. ‹ › 는 한 번에 3일(한 화면)씩 민다.
struct ThreeDayCalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetRangeKind.threeDay.widgetKind,
            provider: CalendarWidgetProvider(range: .days(count: 3, shift: .threeDay))
        ) { entry in
            DayCalendarEntryView(entry: entry, dayCount: 3, shiftKind: .threeDay)
        }
        .configurationDisplayName("3 Days")
        .description("Three days of your schedule on a timeline.")
        .supportedFamilies([.systemLarge])
        // 시스템 기본 콘텐츠 마진을 끈다 — 캘린더는 격자가 가장자리까지 닿아야
        // 셀 폭이 확보되고, 레퍼런스와 같은 밀도가 나온다.
        .contentMarginsDisabled()
    }
}

/// 오늘 하루 시간표. ‹ › 는 하루씩 민다.
struct OneDayCalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetRangeKind.oneDay.widgetKind,
            provider: CalendarWidgetProvider(range: .days(count: 1, shift: .oneDay))
        ) { entry in
            DayCalendarEntryView(entry: entry, dayCount: 1, shiftKind: .oneDay)
        }
        .configurationDisplayName("Today")
        .description("One day of your schedule on a timeline.")
        .supportedFamilies([.systemLarge])
        // 시스템 기본 콘텐츠 마진을 끈다 — 캘린더는 격자가 가장자리까지 닿아야
        // 셀 폭이 확보되고, 레퍼런스와 같은 밀도가 나온다.
        .contentMarginsDisabled()
    }
}

/// 두 시간표 위젯이 공유하는 본문 — 헤더 + 날짜 머리글 + 종일 스트립 + 시간표.
struct DayCalendarEntryView: View {
    let entry: CalendarWidgetEntry
    let dayCount: Int
    let shiftKind: WidgetRangeKind

    @Environment(\.colorScheme) private var colorScheme

    private var calendar: Calendar { .current }

    private var days: [Date] {
        let first = CalendarWidgetProvider.firstDay(
            now: entry.date, offset: entry.offset, calendar: calendar
        )
        return (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    private var today: Date { calendar.startOfDay(for: entry.date) }

    /// 종일 항목만 뽑은 날짜별 사전 — 시간축에 위치가 없어 상단 스트립에 따로 그린다.
    private var allDayItemsByDay: [Date: [WidgetCalendarItem]] {
        entry.snapshot.itemsByDay.compactMapValues { items in
            let allDay = items.filter(\.isAllDay)
            return allDay.isEmpty ? nil : allDay
        }
    }

    var body: some View {
        // 간격 0 — 헤더가 자기 아래 구분선까지 소유한다(위젯 4종 공통). 날짜 머리글의
        // 위 여백은 그 아래에서 따로 준다.
        VStack(spacing: Spacing.zero) {
            CalendarWidgetHeader(
                month: WidgetCalendarTheme.monthName(for: days.first ?? entry.date, calendar: calendar),
                year: WidgetCalendarTheme.yearName(for: days.first ?? entry.date, calendar: calendar),
                shiftKind: shiftKind,
                // 3일 위젯은 한 화면(3일)씩, 1일 위젯은 하루씩.
                shiftStep: dayCount
            )
            if entry.snapshot.hasAccess {
                VStack(spacing: Spacing.xs) {
                    dayHeader
                    allDayStrip
                }
                // 월 위젯 요일 헤더와 같은 규칙 — 구분선 아래 첫 줄의 위 여백을 명시한다.
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.xxs)
                // 시간표와 같은 좌우 인셋 — 안 맞추면 날짜 머리글과 아래 시간표 열이
                // 어긋나 요일이 자기 열 위에 있지 않게 된다.
                .padding(.horizontal, Spacing.xxs)
                // 날짜 머리글 아래에는 선을 긋지 않는다 — 시간표의 0시 눈금선이 바로 아래
                // 오므로, 선이 둘이면 같은 경계가 두 번 그어져 머리글이 갇혀 보인다.
                DayTimelineView(
                    days: days,
                    itemsByDay: entry.snapshot.itemsByDay,
                    calendar: calendar
                )
            } else {
                // 헤더 VStack의 간격이 0이라 안내문 위 여백을 여기서 준다.
                WidgetAccessPrompt().padding(.top, Spacing.xs)
            }
        }
        .dynamicTypeSize(.xSmall)
        .calendarWidgetBackground(colorScheme)
    }

    // MARK: - 날짜 머리글

    /// 1일 위젯은 "31 · **27** · 오늘 · 월요일" 한 줄, 3일 위젯은 열마다 요일 + 날짜.
    @ViewBuilder
    private var dayHeader: some View {
        if dayCount == 1, let day = days.first {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                weekBadge
                Text("\(calendar.component(.day, from: day))")
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(dayColor(day))
                Text(headline(for: day))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: Spacing.zero)
            }
        } else {
            HStack(alignment: .top, spacing: Spacing.zero) {
                // 배지를 날짜 숫자 줄에 맞춘다 — 요일 자리에 같은 스타일의 빈 줄을 세워
                // 높이를 확보하면, 줄높이를 상수로 박지 않고도 두 열이 정확히 정렬된다.
                // 간격은 날짜 열과 같아야 배지가 숫자 줄에 정확히 맞는다.
                VStack(spacing: -Spacing.xxs) {
                    Text(verbatim: " ").font(.caption2).scaleEffect(0.79).hidden()
                    weekBadge
                }
                // 시간 라벨과 같은 정렬 — 주차 배지가 그 숫자들과 세로로 한 줄에 서야 한다.
                .frame(width: WidgetCalendarTheme.gutterWidth, alignment: .center)
                ForEach(days, id: \.self) { day in
                    // 요일과 날짜는 한 덩어리로 읽혀야 한다 — 사이가 뜨면 두 줄로 갈라진다.
                    // spacing이 이미 0인데도 뜨는 건 글자 줄 상자의 위아래 여백 때문이라,
                    // 음수 패딩으로 그만큼 당겨야 실제로 붙는다.
                    VStack(spacing: Spacing.zero) {
                        Text(WidgetCalendarTheme.shortWeekdayName(for: day, calendar: calendar))
                            .font(.caption2)
                            // 레퍼런스(캘린더 앱)와 같은 크기 — @3x 스크린샷에서 요일 줄
                            // 높이가 7.7pt였고, 작업 전 우리는 9.7pt였다(배율 0.79 필요).
                            .scaleEffect(0.79)
                            // 월 위젯 요일 헤더와 같은 규칙 — 일요일 빨강, 토요일 파랑.
                            .foregroundStyle(
                                WidgetCalendarTheme.weekdayColor(
                                    calendar.component(.weekday, from: day)
                                )
                            )
                        Text("\(calendar.component(.day, from: day))")
                            // 레퍼런스 기준 — @3x에서 날짜 줄 11.0pt, 요일 줄 7.7pt로
                            // 날짜가 요일의 **1.4배**다. 요일이 caption2×0.79이므로
                            // 날짜는 caption2×1.1이면 그 비율이 나온다.
                            // (작업 전에는 .subheadline이라 16.7pt로 과하게 컸다.)
                            .font(.caption2.weight(isToday(day) ? .semibold : .regular))
                            .scaleEffect(1.1)
                            .monospacedDigit()
                            .foregroundStyle(dayColor(day))
                            // 월 위젯과 같은 규칙 — 폭은 숫자에 맞추고, 오프셋 없이 줄 상자
                            // 아래 여백에 얹는다.
                            .overlay(alignment: .bottom) {
                                if isToday(day) {
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(Color.primary)
                                        .frame(height: WidgetCalendarTheme.todayUnderlineHeight)
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// 시간 거터와 같은 폭·같은 왼쪽 자리에 붙는 ISO 주차 배지 — 레퍼런스의 좌상단 `31`.
    private var weekBadge: some View {
        Text("\(ISOWeekNumber.number(for: days.first ?? entry.date, calendar: calendar))")
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.tertiary)
    }

    // MARK: - 종일 스트립

    /// 시간축 위 종일 일정 줄 — 종일이 하나도 없으면 아예 자리를 차지하지 않는다.
    @ViewBuilder
    private var allDayStrip: some View {
        let byDay = allDayItemsByDay
        if days.contains(where: { byDay[calendar.startOfDay(for: $0)] != nil }) {
            // 간격 0 — 시간표 열은 거터 이후를 정확히 n등분하므로, 여기에 간격을 주면
            // 종일 칩이 아래 시간표 열과 어긋난다.
            HStack(spacing: Spacing.zero) {
                // 시간표의 거터만큼 비워 종일 칩이 날짜 열과 세로로 맞게 한다.
                Color.clear.frame(width: WidgetCalendarTheme.gutterWidth, height: 0)
                ForEach(days, id: \.self) { day in
                    let allDay = byDay[calendar.startOfDay(for: day)] ?? []
                    VStack(spacing: 1) {
                        // 두 줄까지만 — 그 이상은 시간표가 먹을 높이를 가져간다.
                        ForEach(allDay.prefix(2)) {
                            WidgetItemChip(item: $0)
                                // 월 셀 칩과 같은 인셋 — 날짜 열 경계에 맞닿지 않게.
                                .padding(.horizontal, Spacing.xxs)
                        }
                        // 잘린 종일 일정이 있으면 개수라도 알린다 — 말없이 사라지면
                        // 그날 종일 일정이 둘뿐인 것처럼 읽힌다.
                        if allDay.count > 2 {
                            Text("+\(allDay.count - 2)")
                                .font(.caption2)
                                .scaleEffect(0.85)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Spacing.xxs)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        }
    }

    // MARK: - 보조

    private func isToday(_ day: Date) -> Bool { calendar.startOfDay(for: day) == today }

    private func dayColor(_ day: Date) -> Color {
        let parts = calendar.dateComponents([.year, .month, .day, .weekday], from: day)
        let isHoliday = KoreanHolidayCalculator
            .holidayDays(year: parts.year ?? 0, month: parts.month ?? 0, calendar: calendar)
            .contains(parts.day ?? 0)
        return WidgetCalendarTheme.weekdayColor(parts.weekday ?? 0, isHoliday: isHoliday)
    }

    /// 1일 위젯 부제 — 오늘이면 "Today · 월요일", 아니면 요일만.
    private func headline(for day: Date) -> String {
        let weekday = WidgetCalendarTheme.weekdayName(for: day, calendar: calendar)
        return isToday(day) ? "\(String(localized: "Today")) · \(weekday)" : weekday
    }
}
