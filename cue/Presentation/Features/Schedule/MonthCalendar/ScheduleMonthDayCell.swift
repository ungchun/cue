//
//  ScheduleMonthDayCell.swift
//  cue / Presentation
//

import SwiftUI

/// 월 격자의 하루 칸 — 좌상단 날씨 아이콘(예보가 있는 날) + 우상단 날짜 숫자 + 그날 항목 칩들.
/// 표시 월 밖 칸(nil)은 비워 둔다.
struct ScheduleMonthDayCell: View {
    let day: Int?
    /// 이 칸의 요일(1=일 … 7=토) — 날짜 숫자 색을 가른다.
    let weekday: Int
    let isToday: Bool
    /// 그날 날씨 SF Symbol 이름 — nil이면 그리지 않는다.
    let weatherSymbol: String?
    /// 이미 칸 안 순서(종일 → 시간 → 미완료 → 완료)로 정렬된 항목.
    let items: [WidgetCalendarItem]
    /// 칩 탭 — 상세 시트를 연다.
    let onSelect: (WidgetCalendarItem) -> Void

    /// 오늘 원의 지름 — 두 자리 숫자가 원 안에 들어가도록 caption 글자 크기를 따라간다.
    @ScaledMetric(relativeTo: .caption) private var todayDiameter: CGFloat = 20

    var body: some View {
        if let day {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.zero) {
                    if let weatherSymbol {
                        weatherIcon(weatherSymbol)
                    }
                    Spacer(minLength: Spacing.zero)
                    dayNumber(day)
                }
                ForEach(items) { item in
                    ScheduleMonthItemChip(item: item) { onSelect(item) }
                }
            }
            .padding(Spacing.xxs)
        } else {
            Color.clear
        }
    }

    /// 시스템 날씨 앱처럼 멀티컬러 채움 심볼 — 해는 노랑, 비는 파랑 등 색은 심볼이 정한다.
    /// 날짜 숫자 줄 높이 안에 들어가게 caption 크기를 따른다. 상태 이름이 로케일화돼 있지 않아 VoiceOver에선 숨긴다.
    private func weatherIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .symbolVariant(.fill)
            .symbolRenderingMode(.multicolor)
            .font(.caption)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func dayNumber(_ day: Int) -> some View {
        // 숫자 포맷으로 — 문자열 카탈로그 키를 거치지 않고 로케일 숫자 표기를 따른다.
        let text = Text(day, format: .number)
            .font(.caption.weight(isToday ? .semibold : .regular))
            .monospacedDigit()
        if isToday {
            // 앱 tint가 `.primary`(다크=흰색)라 흰 글씨를 얹으면 다크에서 숫자가 사라진다.
            // 원은 primary, 숫자는 배경색으로 반전해 라이트·다크 모두 대비를 지킨다.
            text
                .foregroundStyle(Color(.systemBackground))
                .frame(minWidth: todayDiameter, minHeight: todayDiameter)
                .background(Circle().fill(Color.primary))
        } else {
            // 오늘 원과 같은 높이를 잡아, 오늘이 있는 주와 없는 주의 칩 시작선이 같아진다.
            text
                .foregroundStyle(Self.dayColor(weekday))
                .frame(minWidth: todayDiameter, minHeight: todayDiameter)
        }
    }

    /// 날짜 숫자 색 — 타임라인 날짜 헤더(`ScheduleView.headerColor`)와 같은 규칙.
    private static func dayColor(_ weekday: Int) -> Color {
        switch weekday {
        case 1: return .red
        case 7: return .blue
        default: return .primary
        }
    }
}
