//
//  ScheduleMonthDayCell.swift
//  cue / Presentation
//

import SwiftUI

/// 월 격자의 하루 칸 — 좌상단 날씨 아이콘(예보가 있는 날) 또는 음력 표기 + 우상단 날짜 숫자 + 그날 항목 칩들.
/// 표시 월 밖 칸(nil)은 비워 둔다.
struct ScheduleMonthDayCell: View {
    let day: Int?
    /// 이 칸의 요일(1=일 … 7=토) — 날짜 숫자 색을 가른다.
    let weekday: Int
    let isToday: Bool
    /// 그날 날씨 SF Symbol 이름 — nil이면 그리지 않는다.
    let weatherSymbol: String?
    /// 그날 음력 표기("10.14") — nil이면 그리지 않는다. 날씨 아이콘과 같은 자리라 날씨가 있으면 양보한다.
    let lunarLabel: String?
    /// 이미 칸 안 순서(종일 → 시간 → 미완료 → 완료)로 정렬된 항목.
    let items: [WidgetCalendarItem]
    /// 칩 탭 — 상세 시트를 연다.
    let onSelect: (WidgetCalendarItem) -> Void

    /// 오늘 원의 지름 — 두 자리 숫자가 원 안에 들어가도록 날짜 숫자(callout) 글자 크기를 따라간다.
    @ScaledMetric(relativeTo: .callout) private var todayDiameter: CGFloat = 26
    /// 라이트 모드 날씨 아이콘 테두리 두께(pt) — 아이콘과 함께 커진다.
    @ScaledMetric(relativeTo: .title3) private var weatherEdgeWidth: CGFloat = 0.8
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let day {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                // 기준선 정렬 — 작은 음력 글씨가 날짜 숫자 가운데가 아니라 바닥선에 앉아 한 단 낮게 보인다.
                HStack(alignment: .firstTextBaseline, spacing: Spacing.zero) {
                    // 좌상단은 한 칸만 — 좁은 칸에 둘 다 넣으면 날짜 숫자가 밀린다. 예보는 오늘 근처
                    // 열흘 남짓뿐이라 날씨를 앞세워도 나머지 날엔 음력이 보인다.
                    if let weatherSymbol {
                        weatherIcon(weatherSymbol)
                    } else if let lunarLabel {
                        lunarText(lunarLabel)
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
    /// 날짜 숫자(callout)보다 한 단계 크게(title3) — 칸 머리에서 날씨가 먼저 눈에 들어오게. 상태 이름이 로케일화돼 있지 않아 VoiceOver에선 숨긴다.
    ///
    /// 멀티컬러 구름·달은 흰색으로 고정이라 라이트 배경에선 사라진다 — 라이트에서만 같은 모양을 상하좌우로
    /// 살짝 밀어 낸 그림자로 얇은 회색 테두리를 둘러 윤곽을 살린다(해·비 색은 그대로).
    private func weatherIcon(_ symbol: String) -> some View {
        let edge = colorScheme == .light ? Color(.tertiaryLabel) : .clear
        let width = colorScheme == .light ? weatherEdgeWidth : 0
        return Image(systemName: symbol)
            .symbolVariant(.fill)
            .symbolRenderingMode(.multicolor)
            .font(.title3)
            .shadow(color: edge, radius: 0, x: width, y: 0)
            .shadow(color: edge, radius: 0, x: -width, y: 0)
            .shadow(color: edge, radius: 0, x: 0, y: width)
            .shadow(color: edge, radius: 0, x: 0, y: -width)
            .accessibilityHidden(true)
    }

    /// 날짜 숫자(callout)보다 작고 흐리게 — 곁들이는 정보라 날짜를 가리지 않게.
    /// 숫자를 그대로 찍는 표기라 문자열 카탈로그를 거치지 않는다(verbatim).
    private func lunarText(_ label: String) -> some View {
        Text(verbatim: label)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .lineLimit(1)
            // 칸 폭이 50pt 남짓이라 "윤10.14"나 큰 글자 크기에선 넘친다 — 잘려 "10.1…"로 오독되느니 줄인다.
            .minimumScaleFactor(0.7)
            // VoiceOver는 "10.14"를 소수로 읽어 오해를 부른다. 바르게 읽히는 라벨("음력 10월 14일")은
            // 번역 문자열이 필요해 두지 않고, 곁들이는 정보라 숨긴다 — 날짜 숫자·항목은 그대로 읽힌다.
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func dayNumber(_ day: Int) -> some View {
        // 숫자 포맷으로 — 문자열 카탈로그 키를 거치지 않고 로케일 숫자 표기를 따른다.
        let text = Text(day, format: .number)
            .font(.callout.weight(isToday ? .semibold : .regular))
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
