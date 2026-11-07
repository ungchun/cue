//
//  ScheduleMonthItemChip.swift
//  cue / Presentation
//

import SwiftUI

/// 월 격자 칸 안의 항목 한 줄. 종류를 한눈에 가르도록 네 모양으로 그린다:
/// - 종일 일정: 캘린더 색으로 채운 블록, 글자 가운데
/// - 시간 일정: 옅은 캘린더 색 배경 + 캘린더 색 글씨
/// - 할일 미완료: 리스트 색 빈 원 + 제목
/// - 할일 완료: 리스트 색 체크 원 + 제목, 전체를 흐리게
///
/// 위젯의 `WidgetItemChip`과 같은 시각 언어 — 위젯 타깃 전용이라 앱에서 재사용할 수 없어 따로 둔다.
/// 누르면 상세 시트를 연다(`onSelect`).
struct ScheduleMonthItemChip: View {
    let item: WidgetCalendarItem
    let onSelect: () -> Void

    /// 할일 원 지름 — 제목(caption2)보다 작게, 글자 크기 설정을 따라 함께 커진다.
    @ScaledMetric(relativeTo: .caption2) private var reminderIconSize: CGFloat = 7

    /// 칩 모서리 — 좁은 칸에서 글자 자리를 덜 깎도록 작게.
    private static let cornerRadius: CGFloat = 3
    /// 시간 일정 배경 농도 — 타임라인 `EventRow` 캡슐과 같은 값.
    private static let softBackgroundOpacity: Double = 0.18
    /// 완료 할일 농도 — 색은 유지하고 살짝만 물러나게.
    private static let completedOpacity: Double = 0.5

    var body: some View {
        // plain — 기본 스타일의 tint·눌림 강조가 종류별 칩 모양을 바꾸지 않게.
        Button(action: onSelect) {
            content
                // 칸 VStack이 남는 높이를 칩에 나눠 주지 않게 — 칩은 항상 한 줄 높이다.
                .fixedSize(horizontal: false, vertical: true)
                // 할일 칩은 배경이 없어 글자 뒤 빈 자리까지 눌리게 한다.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 원 아이콘 이름 없이 제목만 읽는다. 버튼이라 "버튼"이 함께 읽힌다.
        .accessibilityLabel(Text(item.title))
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .allDayEvent:
            titleLine(centered: true)
                // 캘린더 색으로 꽉 찬 배경 위라 시스템 본문색 대신 흰색으로 대비를 확보한다.
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.xxs)
                .padding(.vertical, Spacing.xxs)
                .background(shape.fill(eventColor))
        case .timedEvent:
            // 타임라인 `EventRow` 캡슐과 같은 언어 — 옅은 캘린더 색 배경 + 캘린더 색 글씨.
            // 종일(꽉 찬 색)과는 채움 농도로만 갈라 칸이 단순하게 읽힌다.
            titleLine(centered: false)
                .fontWeight(.semibold)
                .foregroundStyle(eventColor)
                .padding(.horizontal, Spacing.xxs)
                .padding(.vertical, Spacing.xxs)
                .background(shape.fill(eventColor.opacity(Self.softBackgroundOpacity)))
        case .reminder:
            HStack(spacing: Spacing.xxs) {
                // caption2가 가장 작은 텍스트 스타일이라 그보다 작게는 크기를 직접 잡는다(ScaledMetric으로
                // Dynamic Type은 따라감). 작아진 만큼 선이 가늘어 보여 굵기를 올린다.
                // 완료는 체크 없이 리스트 색으로 채운 원. 완료·미완료가 같은 프레임이라 크기가 같다.
                Image(systemName: item.isCompleted ? "circle.fill" : "circle")
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.black)
                    .frame(width: reminderIconSize, height: reminderIconSize)
                    .foregroundStyle(reminderColor)
                titleLine(centered: false)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, Spacing.xxs)
            .padding(.vertical, Spacing.xxs)
            // 끝낸 일은 리스트 색을 그대로 둔 채 흐리게 — 어느 리스트였는지는 읽히되 지금 할 일보다 덜 띈다.
            .opacity(item.isCompleted ? Self.completedOpacity : 1)
        }
    }

    /// 제목 한 줄 — 넘치면 말줄임표 없이 칸 끝에서 자른다.
    ///
    /// 칸이 좁아 `...`가 폭을 먹으면 제목이 한두 글자만 남는다. 글자는 이상적 폭 그대로 두고
    /// 바깥 프레임(`minWidth: 0`이라 글자 폭에 끌려 늘어나지 않음)에서 잘라야 같은 자리에 더 들어간다.
    /// 가운데 정렬은 Spacer가 맡아 들어갈 때만 가운데에 서고, 넘치면 0으로 눌려 앞글자부터 보인다.
    private func titleLine(centered: Bool) -> some View {
        HStack(spacing: Spacing.zero) {
            if centered { Spacer(minLength: Spacing.zero) }
            Text(item.title)
                .font(.caption2)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: Spacing.zero)
        }
        .frame(minWidth: Spacing.zero, maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Self.cornerRadius)
    }

    /// 캘린더 색. 없거나 파싱 실패면 시스템 accent — 타임라인 `EventRow`와 같은 폴백.
    private var eventColor: Color {
        guard let hex = item.colorHex, let parsed = Color(hex: hex) else { return .accentColor }
        return parsed
    }

    /// 할일 리스트 색. 없으면 secondary — 빈 원은 중립색이어도 "할일"로 읽힌다.
    private var reminderColor: Color {
        guard let hex = item.colorHex, let parsed = Color(hex: hex) else { return .secondary }
        return parsed
    }
}
