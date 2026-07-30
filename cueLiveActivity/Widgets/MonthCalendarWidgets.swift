//
//  MonthCalendarWidgets.swift
//  cueLiveActivity
//
//  월 캘린더 위젯 두 종 — 좌우로 달을 넘기는 이동형과, 항상 이번 달만 보여주는 고정형.
//  본문(`MonthWidgetView`)은 같고 헤더의 셰브런 유무와 오프셋만 다르다.
//

import SwiftUI
import WidgetKit

/// 좌우 ‹ › 로 달을 넘기는 월 캘린더. 넘긴 상태는 그날 자정까지만 유지되고 다음 날 오늘로 돌아온다.
struct MonthCalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetRangeKind.month.widgetKind,
            provider: CalendarWidgetProvider(
                range: .month(shift: .month), requiresPremium: true
            )
        ) { entry in
            MonthWidgetEntryView(entry: entry, shiftKind: .month)
        }
        // 제목 옆 자물쇠는 **구독 전에만** 붙는다.
        .configurationDisplayName(widgetGalleryName("Month", requiresPremium: true))
        // 설명은 비운다 — 이름만으로 무엇인지 충분히 읽히고, 미리보기가 그 아래에서
        // 실제 모습을 보여준다. `description`은 필수 modifier라 지울 수는 없다.
        .description("")
        .supportedFamilies([.systemLarge])
        // 시스템 기본 콘텐츠 마진을 끈다 — 캘린더는 격자가 가장자리까지 닿아야
        // 셀 폭이 확보되고, 레퍼런스와 같은 밀도가 나온다.
        .contentMarginsDisabled()
    }
}

/// 항상 오늘이 속한 달만 보여주는 월 캘린더 — 이동 버튼이 없어 달력 면적을 온전히 쓴다.
struct FixedMonthCalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: CalendarWidgetKind.fixedMonth,
            provider: CalendarWidgetProvider(range: .month(shift: nil))
        ) { entry in
            MonthWidgetEntryView(entry: entry, shiftKind: nil)
        }
        // 무료로 쓸 수 있는 유일한 캘린더 위젯 — 자물쇠를 붙이지 않는다.
        .configurationDisplayName(widgetGalleryName("This Month", requiresPremium: false))
        .description("")
        .supportedFamilies([.systemLarge])
        // 시스템 기본 콘텐츠 마진을 끈다 — 캘린더는 격자가 가장자리까지 닿아야
        // 셀 폭이 확보되고, 레퍼런스와 같은 밀도가 나온다.
        .contentMarginsDisabled()
    }
}

/// 두 월 위젯이 공유하는 본문.
struct MonthWidgetEntryView: View {
    let entry: CalendarWidgetEntry
    /// `nil`이면 셰브런을 그리지 않는다(고정형).
    let shiftKind: WidgetRangeKind?

    @Environment(\.colorScheme) private var colorScheme

    private var calendar: Calendar { .current }

    private var grid: MonthCalendarGrid {
        MonthCalendarGrid(now: entry.date, monthOffset: entry.offset, calendar: calendar)
    }

    /// 표시 월의 1일 — 헤더 제목(연·월)을 로케일 포맷으로 뽑는 기준.
    private var displayedMonth: Date {
        calendar.date(from: DateComponents(year: grid.year, month: grid.month, day: 1)) ?? entry.date
    }

    /// 스냅샷(날짜 키)을 표시 월의 **일 숫자 키**로 눕힌다 — 셀이 일 숫자만 알기 때문.
    private var itemsByDay: [Int: [WidgetCalendarItem]] {
        var result: [Int: [WidgetCalendarItem]] = [:]
        for (day, items) in entry.snapshot.itemsByDay {
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            guard parts.year == grid.year, parts.month == grid.month, let number = parts.day else { continue }
            result[number] = items
        }
        return result
    }

    var body: some View {
        // 간격 0 — 헤더가 자기 아래 구분선까지 소유하므로, 여기에 간격을 주면
        // 선과 격자 사이가 떠서 위젯 4종의 상단 바 높이가 어긋난다.
        VStack(spacing: Spacing.zero) {
            CalendarWidgetHeader(
                month: WidgetCalendarTheme.monthName(for: displayedMonth, calendar: calendar),
                year: WidgetCalendarTheme.yearName(for: displayedMonth, calendar: calendar),
                shiftKind: shiftKind
            )
            if entry.snapshot.hasAccess {
                // 잠금은 **격자에만** 건다 — 헤더의 달·연도는 남겨야 이 위젯이 무엇인지
                // 알 수 있고, 날짜 격자도 비쳐 보여야 "무엇을 잃고 있는지"가 전달된다.
                // 잠겼으면 **항목을 아예 넘기지 않는다.** 재질로 덮기만 하면 흐릿하게나마
                // 제목이 비쳐, 돈을 안 낸 사람에게 내용이 새어 나간다.
                MonthWidgetView(grid: grid, itemsByDay: entry.isLocked ? [:] : itemsByDay)
                    .premiumLocked(entry.isLocked)
            } else {
                // 헤더 VStack의 간격이 0이라 안내문 위 여백을 여기서 준다.
                WidgetAccessPrompt().padding(.top, Spacing.xs)
            }
        }
        // 표준(.large) 타입 램프로는 셀 하나에 칩이 한 줄도 안 들어간다 — LA 일정 위젯과
        // 같은 이유로 밀도를 확보하려고 타입 스케일을 고정한다.
        .dynamicTypeSize(.xSmall)
        .calendarWidgetBackground(colorScheme)
    }
}
