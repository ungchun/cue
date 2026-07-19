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
    /// 날짜별 일정 점(오늘 제외). 각 날 이벤트 색을 그 날짜 숫자 아래에 작은 원으로 그린다.
    var eventDots: [LiveDayEventDots] = []

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: Spacing.zero) {
            ForEach(weekDates, id: \.timeIntervalSinceReferenceDate) { date in
                VStack(spacing: Spacing.xxs) {
                    Text(weekdaySymbol(date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(dayNumber(date))
                        .font(.callout)
                        .foregroundStyle(.primary)
                    // 숫자 아래 마커 — 오늘은 밑줄 박스, 그 외 날은 일정 점. 같은 행 슬롯이라
                    // 오늘 밑줄과 다른 날 점이 같은 세로 위치에 정렬된다.
                    marker(for: date)
                }
                .frame(maxWidth: .infinity)
            }
        }
        // 월/카운트 헤더와 너무 붙지 않게 위에 여백 — 하단 영역에서 살짝 가운데로 내려온 느낌.
        .padding(.top, Spacing.sm)
    }

    /// 날짜 숫자 아래 마커 — 오늘은 밑줄 박스, 그 외 날은 일정 점(캘린더 색, 없으면 accent).
    /// 둘 다 같은 높이를 예약해 모든 칸의 숫자·마커가 같은 세로 기준선에 정렬된다.
    @ViewBuilder
    private func marker(for date: Date) -> some View {
        if isToday(date) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.primary)
                .frame(width: 18, height: 3)
                .frame(height: 4)
        } else {
            HStack(spacing: Spacing.xxs) {
                ForEach(Array(colorHexes(for: date).enumerated()), id: \.offset) { _, hex in
                    Circle()
                        .fill(Color(hex: hex) ?? .accentColor)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    /// 그 날짜의 일정 점 색 목록 — `eventDots`에서 같은 날을 찾아 반환(없으면 빈 배열).
    private func colorHexes(for date: Date) -> [String] {
        eventDots.first { calendar.isDate($0.dayStart, inSameDayAs: date) }?.colorHexes ?? []
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
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMM")   // ko "6월" / en "June"
        return formatter
    }()

    private static let symbolFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current   // veryShortWeekdaySymbols — 기기 로케일(ko:일월화… / en:S M T…)
        return formatter
    }()
}
