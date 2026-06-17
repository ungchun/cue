//
//  WeekCalendarStrip.swift
//  cueLiveActivity
//
//  Dynamic Island 확장뷰 — 이번 주 캘린더 그리드(요일 헤더 + 7일, 오늘은 채운 원).
//  할일/일정 위젯이 공유한다. 월/카운트는 위젯이 leading/trailing 영역에 따로 배치한다
//  (전체 폭을 써 좌상단·우상단에 붙이려고). 그리드는 `now`로 위젯이 직접 계산.
//

import SwiftUI

struct WeekCalendarStrip: View {
    let now: Date

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: Spacing.zero) {
            ForEach(weekDates, id: \.timeIntervalSinceReferenceDate) { date in
                VStack(spacing: Spacing.xxs) {
                    Text(weekdaySymbol(date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    // 오늘 표시 — 숫자에 직접 overlay(아래·가운데)로 사각형 밑줄을 붙여 숫자 정중앙에 정렬.
                    Text(dayNumber(date))
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .padding(.bottom, Spacing.xs)
                        .overlay(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(isToday(date) ? Color.primary : Color.clear)
                                .frame(width: 18, height: 3)
                        }
                }
                .frame(maxWidth: .infinity)
            }
        }
        // 월/카운트 헤더와 너무 붙지 않게 위에 여백 — 하단 영역에서 살짝 가운데로 내려온 느낌.
        .padding(.top, Spacing.sm)
    }

    /// 좌상단 월 라벨 — 위젯 leading 영역에서 쓴다. "6월".
    static func monthLabel(_ now: Date) -> String {
        monthFormatter.string(from: now)
    }

    // MARK: - 날짜 계산 (locale·timezone은 Calendar.current 따름)

    /// 이번 주 7일 — 사용자 지역의 주 시작 요일(`firstWeekday`) 기준.
    private var weekDates: [Date] {
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let start = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: now)
    }

    private func dayNumber(_ date: Date) -> String {
        "\(calendar.component(.day, from: date))"
    }

    private func weekdaySymbol(_ date: Date) -> String {
        let symbols = Self.symbolFormatter.veryShortWeekdaySymbols ?? []
        let index = calendar.component(.weekday, from: date) - 1   // 0 = 일요일
        return symbols.indices.contains(index) ? symbols[index] : ""
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월"   // "6월"
        return formatter
    }()

    private static let symbolFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")   // veryShortWeekdaySymbols = 일월화수목금토
        return formatter
    }()
}
