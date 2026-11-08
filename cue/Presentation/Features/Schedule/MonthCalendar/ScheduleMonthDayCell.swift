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

    /// 오늘 밑줄 두께 — 날짜 숫자 글자 크기를 따라간다.
    @ScaledMetric(relativeTo: .footnote) private var todayUnderlineHeight: CGFloat = 2
    /// 라이트 모드 날씨 아이콘 테두리 두께(pt) — 아이콘과 함께 커진다.
    @ScaledMetric(relativeTo: .footnote) private var weatherEdgeWidth: CGFloat = 0.8
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
                    // 음력과 날짜 숫자가 붙어 "10.1018"처럼 읽히지 않게 최소 틈을 둔다.
                    Spacer(minLength: Spacing.xxs)
                    dayNumber(day)
                }
                ForEach(items) { item in
                    ScheduleMonthItemChip(item: item) { onSelect(item) }
                }
            }
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.xxs)
        } else {
            Color.clear
        }
    }

    /// 시스템 날씨 앱처럼 멀티컬러 채움 심볼 — 해는 노랑, 비는 파랑 등 색은 심볼이 정한다.
    /// 날짜 숫자와 같은 크기(footnote) — 칸 머리 한 줄의 높이를 맞춘다. 상태 이름이 로케일화돼 있지 않아 VoiceOver에선 숨긴다.
    ///
    /// 멀티컬러 구름·달은 흰색으로 고정이라 라이트 배경에선 사라진다 — 라이트에서만 같은 모양을 상하좌우로
    /// 살짝 밀어 낸 그림자로 얇은 회색 테두리를 둘러 윤곽을 살린다(해·비 색은 그대로).
    private func weatherIcon(_ symbol: String) -> some View {
        let edge = colorScheme == .light ? Color(.tertiaryLabel) : .clear
        let width = colorScheme == .light ? weatherEdgeWidth : 0
        return Image(systemName: symbol)
            .symbolVariant(.fill)
            .symbolRenderingMode(.multicolor)
            .font(.footnote)
            .shadow(color: edge, radius: 0, x: width, y: 0)
            .shadow(color: edge, radius: 0, x: -width, y: 0)
            .shadow(color: edge, radius: 0, x: 0, y: width)
            .shadow(color: edge, radius: 0, x: 0, y: -width)
            .accessibilityHidden(true)
    }

    /// 날짜 숫자(footnote)보다 작고 흐리게(tertiary) — 곁들이는 정보라 날짜보다 먼저 눈에 띄지 않게.
    /// 고정폭 숫자는 쓰지 않는다 — "1"이 넓어져 좁은 칸에서 날짜 숫자와 붙는다.
    /// 숫자를 그대로 찍는 표기라 문자열 카탈로그를 거치지 않는다(verbatim).
    private func lunarText(_ label: String) -> some View {
        Text(verbatim: label)
            .font(.caption2)
            // caption2가 가장 작은 텍스트 스타일이라 한 단 더 줄이는 건 시스템 보조 글자 배율로 — 고정 크기 없이 동적 글꼴을 따른다.
            .textScale(.secondary)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            // 칸 폭이 50pt 남짓이라 "윤10.14"나 큰 글자 크기에선 넘친다 — 잘려 "10.1…"로 오독되느니 줄인다.
            .minimumScaleFactor(0.7)
            // VoiceOver는 "10.14"를 소수로 읽어 오해를 부른다. 바르게 읽히는 라벨("음력 10월 14일")은
            // 번역 문자열이 필요해 두지 않고, 곁들이는 정보라 숨긴다 — 날짜 숫자·항목은 그대로 읽힌다.
            .accessibilityHidden(true)
    }

    /// 칸 오른쪽에 붙인 날짜 숫자. 오늘은 빨간 굵은 숫자 + 밑줄 — 원으로 감싸면 좁은 칸에서 숫자보다
    /// 원이 먼저 보여 무겁다. 밑줄 자리는 모든 날이 똑같이 비워 둬, 오늘이 있는 주와 없는 주의 칩 시작선이 같다.
    private func dayNumber(_ day: Int) -> some View {
        // 숫자 포맷으로 — 문자열 카탈로그 키를 거치지 않고 로케일 숫자 표기를 따른다.
        Text(day, format: .number)
            .font(.footnote.weight(isToday ? .bold : .regular))
            .monospacedDigit()
            .foregroundStyle(isToday ? Color.red : Self.dayColor(weekday))
            .padding(.bottom, todayUnderlineHeight)
            .overlay(alignment: .bottom) {
                if isToday {
                    Capsule()
                        .fill(Color.red)
                        .frame(height: todayUnderlineHeight)
                        // 숫자엔 내림획이 없어 글자 아래 여백이 그대로 틈으로 보인다 — 그만큼 끌어올려 숫자에 붙인다.
                        .offset(y: -Spacing.xxs)
                }
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
