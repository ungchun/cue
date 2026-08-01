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
            provider: CalendarWidgetProvider(
                range: .days(count: 3, shift: .threeDay), requiresPremium: true
            )
        ) { entry in
            DayCalendarEntryView(entry: entry, dayCount: 3, shiftKind: .threeDay)
        }
        .configurationDisplayName(widgetGalleryName("3 Days", requiresPremium: true))
        .description("")
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
            provider: CalendarWidgetProvider(
                range: .days(count: 1, shift: .oneDay), requiresPremium: true
            )
        ) { entry in
            DayCalendarEntryView(entry: entry, dayCount: 1, shiftKind: .oneDay)
        }
        .configurationDisplayName(widgetGalleryName("1 Day", requiresPremium: true))
        .description("")
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
    ///
    /// 잠겼으면 비운다. 시간표만 가리고 여기를 두면 종일 일정 제목이 그대로 새어 나간다.
    private var allDayItemsByDay: [Date: [WidgetCalendarItem]] {
        guard !entry.isLocked else { return [:] }
        return entry.snapshot.itemsByDay.compactMapValues { items in
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
                .padding(.horizontal, WidgetCalendarTheme.timelineInset)
                // 날짜 머리글 아래에는 선을 긋지 않는다 — 시간표의 0시 눈금선이 바로 아래
                // 오므로, 선이 둘이면 같은 경계가 두 번 그어져 머리글이 갇혀 보인다.
                // 잠금은 **시간표에만** 건다 — 날짜 머리글은 남겨야 이 위젯이 무엇인지
                // 알 수 있다. 항목은 아예 안 넘긴다: 덮기만 하면 흐릿하게 비쳐 새어 나간다.
                DayTimelineView(
                    days: days,
                    itemsByDay: entry.isLocked ? [:] : entry.snapshot.itemsByDay,
                    calendar: calendar
                )
                .premiumLocked(entry.isLocked)
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
                // 배지도 **거터 폭 안에서 가운데** — 아래 시간 라벨과 같은 규칙이라야
                // 왼쪽 열에 세로로 한 줄로 선다. 이 프레임이 없으면 배지가 자기 글자 폭만
                // 차지해 시간 라벨보다 왼쪽으로 밀린다(실기기에서 확인).
                weekBadge
                    .frame(width: WidgetCalendarTheme.gutterWidth, alignment: .center)
                Text("\(calendar.component(.day, from: day))")
                    // 1일 위젯에서는 이 줄이 헤드라인이다 — "오늘이 며칠인지"가 첫 정보라
                    // 옆의 요일보다 확실히 앞서 읽혀야 한다. 크기와 굵기를 함께 준다.
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(dayColor(day))
                Text(headline(for: day))
                    // 날짜보다 한 단계 물러난다 — 요일은 날짜를 보완하는 정보다.
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    // 날짜와 한 덩어리로 붙어 읽히지 않게 조금 띄운다. HStack의 spacing을
                    // 키우면 배지↔날짜 사이까지 벌어지므로 여기서만 준다.
                    .padding(.leading, Spacing.xxs)
                Spacer(minLength: Spacing.zero)
            }
        } else {
            HStack(alignment: .top, spacing: Spacing.zero) {
                // 배지를 날짜 숫자 줄에 맞춘다 — 요일 자리에 같은 스타일의 빈 줄을 세워
                // 높이를 확보하면, 줄높이를 상수로 박지 않고도 두 열이 정확히 정렬된다.
                // 간격은 날짜 열과 같아야 배지가 숫자 줄에 정확히 맞는다.
                VStack(spacing: -Spacing.xxs) {
                    Text(verbatim: " ").font(.caption2).scaleEffect(0.84).hidden()
                    weekBadge
                }
                // 시간 라벨과 같은 정렬 — 주차 배지가 그 숫자들과 세로로 한 줄에 서야 한다.
                .frame(width: WidgetCalendarTheme.gutterWidth, alignment: .center)
                ForEach(days, id: \.self) { day in
                    // 요일과 날짜는 한 덩어리로 읽혀야 한다 — 사이가 뜨면 두 줄로 갈라진다.
                    // 음수 간격인 건 글자 줄 상자에 위아래 여백이 이미 들어 있어서다.
                    // 0으로 두면 그 여백만큼 떠 보인다.
                    VStack(spacing: -Spacing.xxs) {
                        Text(WidgetCalendarTheme.shortWeekdayName(for: day, calendar: calendar))
                            .font(.caption2)
                            // 요일과 날짜의 크기 차를 좁히되, 날짜가 앞서 읽히는 선은 지킨다.
                            .scaleEffect(0.84)
                            // 월 위젯 요일 헤더와 같은 규칙 — 일요일 빨강, 토요일 파랑.
                            .foregroundStyle(
                                WidgetCalendarTheme.weekdayColor(
                                    calendar.component(.weekday, from: day)
                                )
                            )
                        Text("\(calendar.component(.day, from: day))")
                            // 요일보다 크되 과하지 않게 — 열이 셋뿐이라 날짜가 크면
                            // 머리글이 시간표보다 무거워 보인다. 오늘만 굵기로 가른다.
                            .font(.caption2.weight(isToday(day) ? .semibold : .regular))
                            .scaleEffect(1.0)
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
    ///
    /// 그 해의 몇 번째 주인지(ISO 8601). **아래 시간 라벨과 같은 크기**로 그린다 —
    /// 같은 거터에 세로로 늘어서는 숫자들이라 크기가 다르면 한 줄로 안 읽힌다.
    private var weekBadge: some View {
        Text("\(ISOWeekNumber.number(for: days.first ?? entry.date, calendar: calendar))")
            .font(.caption2)
            .scaleEffect(WidgetCalendarTheme.hourLabelScale)
            .monospacedDigit()
            .foregroundStyle(.tertiary)
    }

    // MARK: - 종일 스트립

    /// 제목을 붙여 그릴 종일 일정 개수 — 그 이상은 색 막대로 남긴다.
    ///
    /// 열 폭에서 역산한다(→ `AllDayStripLimits`). 3일 위젯은 열이 100pt라 2개,
    /// 1일 위젯은 300pt라 3개가 나온다.
    private var titledAllDayLimit: Int {
        AllDayStripLimits.titledCount(columnWidth: WidgetCalendarTheme.dayColumnWidth(dayCount: dayCount))
    }

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
                    // 앞의 몇 개는 **제목 칩**으로 가로로 늘어놓고, 나머지는 색 막대로 남긴다.
                    //
                    // 세로로 쌓지 않는 이유: 그만큼 시간표 높이를 가져가는데, 24시간을 담는
                    // 화면에서 그 손실이 크다. 가로로 두면 종일 줄은 한 줄로 끝난다.
                    //
                    // 칩 개수 한계는 **열 폭이 정한다**(→ `AllDayStripLimits`).
                    // 3일 위젯은 열이 100pt뿐이라 2개면 50pt씩 — "건강검진"(34pt)이 겨우
                    // 들어간다. 1일은 300pt라 3개까지 99pt씩으로 여유롭다.
                    HStack(spacing: 1) {
                        ForEach(allDay.prefix(titledAllDayLimit)) {
                            WidgetItemChip(item: $0)
                        }
                        // 자리를 못 받은 것들 — 제목은 못 보여도 **몇 개가 더 있는지**와
                        // 무슨 색인지는 남긴다. 아무것도 안 그리면 그날 종일 일정이
                        // 앞의 몇 개뿐인 것처럼 읽힌다.
                        //
                        // 개수를 막는 이유: 막대는 고정 폭이라 스무 개가 붙으면 80pt를
                        // 먹어 제목 칩을 밀어낸다. 그 지점부터는 "몇 개인지"도 못 세므로
                        // 더 그릴 값이 없다.
                        ForEach(allDay.dropFirst(titledAllDayLimit).prefix(AllDayStripLimits.barLimit)) { item in
                            RoundedRectangle(cornerRadius: WidgetCalendarTheme.chipCornerRadius)
                                .fill(WidgetCalendarTheme.color(of: item))
                                .frame(width: AllDayStripLimits.barWidth)
                        }
                    }
                    .frame(height: MonthWidgetMetrics.chipLine.rounded(.up))
                    // 월 셀 칩과 같은 인셋 — 날짜 열 경계에 맞닿지 않게.
                    .padding(.horizontal, Spacing.xxs)
                    // 폭을 열 몫으로 못 박고 **그 뒤에 잘라낸다**.
                    //
                    // `maxWidth: .infinity`만으로는 부족하다 — 그건 이 뷰가 부모에게 보고하는
                    // 크기만 정할 뿐, 안쪽 HStack의 자식들은 여전히 제 이상적 폭으로 눕는다.
                    // 제목이 길면 그대로 옆 날짜 열까지 번진다. 시간표 블록은 열 경계를
                    // 지키는데 종일 줄만 안 지키면 같은 화면에서 규칙이 갈린다.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
                }
            }
        }
    }

    // MARK: - 보조

    private func isToday(_ day: Date) -> Bool { calendar.startOfDay(for: day) == today }

    /// 날짜 머리글의 숫자 색 — 일요일·공휴일 빨강, 토요일 파랑.
    ///
    /// 공휴일 판정은 **잠금과 무관하게** 스냅샷 원본에서 읽는다. 시간표는 가려도 날짜 머리글은
    /// 남기는 화면이라(→ `body` 주석), 여기서 색까지 빠지면 무료 사용자에게는 공휴일이 없는
    /// 달력이 된다. 공휴일은 어차피 공개 정보라 가릴 것도 없다.
    private func dayColor(_ day: Date) -> Color {
        let isHoliday = entry.snapshot.items(on: day, calendar: calendar).contains(where: \.isHoliday)
        let weekday = calendar.component(.weekday, from: day)
        return WidgetCalendarTheme.weekdayColor(weekday, isHoliday: isHoliday)
    }

    /// 1일 위젯 부제 — 오늘이면 "Today · 월요일", 아니면 요일만.
    private func headline(for day: Date) -> String {
        let weekday = WidgetCalendarTheme.weekdayName(for: day, calendar: calendar)
        return isToday(day) ? "\(String(localized: "Today")) · \(weekday)" : weekday
    }
}
