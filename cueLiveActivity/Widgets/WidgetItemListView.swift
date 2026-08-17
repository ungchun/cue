//
//  WidgetItemListView.swift
//  cueLiveActivity
//
//  캘린더 옆에 세우는 다가오는 항목 목록 — 일정 위젯과 할일 위젯이 공유한다.
//  무엇을 담을지는 `UpcomingItemPicker`가 정하고, 여기서는 그리기만 한다.
//

import AppIntents
import SwiftUI

struct WidgetItemListView: View {
    let items: [WidgetCalendarItem]
    /// 항목이 하나도 없을 때 띄울 문구 — "오늘 일정 없음" / "할 일 없음".
    let emptyText: LocalizedStringKey
    /// 지남(overdue) 판정 기준 시각 — 타임라인 entry의 시각을 그대로 받는다.
    let now: Date
    let calendar: Calendar

    var body: some View {
        // 높이를 **재서 나눈다.**
        //
        // `maxHeight: .infinity`로는 안 된다 — 그건 상한만 정할 뿐, 줄의 **고유 높이**
        // (제목 + 시각 두 줄)가 여전히 바닥이라 네 줄의 합이 위젯보다 크면 그대로
        // 넘친다(실기기에서 네 번째 줄이 잘렸다). 잰 높이를 정확히 4등분해 넘겨야
        // 줄이 실제로 눌린다.
        //
        // 여기서 `GeometryReader`가 안전한 이유: 목록은 `HStack`의 한 칸이라 부모가
        // 폭·높이를 모두 확정해 준다(높이를 정하지 못하던 `VStack` 안과 다르다).
        GeometryReader { geometry in
            let slot = geometry.size.height / CGFloat(UpcomingListMetrics.rowCount)

            if items.isEmpty {
                Text(emptyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    // 빈 안내는 목록 자리 한가운데 — 왼쪽 위에 붙으면 잘린 목록처럼 보인다.
                    .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                // 줄들을 **자연 높이로** 쌓고 간격만 준다 — 칸(`slot`)을 꽉 채우면
                // 남는 높이가 줄 사이로 흩어져 성기게 보인다. 다만 그렇게 쌓은 높이가
                // 위젯을 넘으면 안 되므로, 넘칠 때만 칸에 맞춰 눌러 담는다.
                let natural = Self.rowContentHeight * CGFloat(UpcomingListMetrics.rowCount)
                    + Self.rowSpacing * CGFloat(UpcomingListMetrics.rowCount - 1)
                let fits = natural <= geometry.size.height

                VStack(alignment: .leading, spacing: fits ? Self.rowSpacing : Spacing.zero) {
                    ForEach(items.prefix(UpcomingListMetrics.rowCount)) { item in
                        row(item)
                            .frame(
                                width: geometry.size.width,
                                height: fits ? Self.rowContentHeight : slot,
                                alignment: .leading
                            )
                            // 넘치는 글자는 잘라낸다 — 반쯤 걸친 줄보다 잘린 줄이 낫다.
                            .clipped()
                    }
                }
                // 남는 자리를 위아래로 **나눠** 목록 덩어리를 세로 가운데 세운다.
                // 위 정렬이면 항목이 적을 때 아래만 휑하게 남아 목록이 잘린 것처럼 보인다.
                .frame(height: geometry.size.height, alignment: .center)
            }
        }
    }

    /// 항목 한 줄 — 마커 + (제목 / 시각) 두 줄.
    ///
    /// 마커는 월 셀 칩과 **같은 어휘**를 쓴다(→ `WidgetItemChip`): 시간 일정은 세로 막대,
    /// 종일은 캘린더 색으로 채운 사각, 할일은 원. 같은 위젯 묶음에서 같은 모양이 다른 뜻을
    /// 갖으면 안 된다.
    private func row(_ item: WidgetCalendarItem) -> some View {
        // 마커와 글자 사이 — 붙어 있으면 원·사각이 제목의 첫 글자처럼 읽힌다.
        HStack(alignment: .center, spacing: Spacing.sm) {
            // 미완료 할일의 원은 **완료 버튼**이다 — LA 체크박스와 같은 문법.
            // LA의 인텐트가 아니라 위젯 전용(`CompleteReminderWidgetIntent`)을 쓴다 —
            // LA 쪽은 앱 프로세스에서 돌아 콜드 런치가 끼면 완료가 수 초 늦었다.
            // 제목 쪽 탭은 지금처럼 앱을 연다.
            if item.supportsCompletion, let reminderID = item.reminderID {
                Button(intent: CompleteReminderWidgetIntent(reminderID: reminderID)) {
                    marker(for: item)
                        // 탭 영역을 마커(16pt)보다 넓게 — 위젯 버튼은 한 번에 맞히기 어렵다.
                        .padding(Spacing.xs)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                // 패딩이 레이아웃을 밀지 않게 마커 크기만 차지한다 — 버튼이 아닌 행과
                // 제목 시작점이 같아야 목록이 한 줄로 읽힌다.
                .frame(width: Self.markerDiameter, height: Self.markerDiameter)
                // `invalidatableContent()`는 쓰지 않는다 — 버튼별이 아니라 **위젯 단위**로
                // 무효화가 걸려, 하나를 탭해도 표시된 원 네 개가 전부 깜빡였다(실기기).
            } else {
                marker(for: item)
            }
            // 제목과 시각은 **한 덩어리**로 붙어 읽혀야 한다. 음수 간격인 건 글자 줄
            // 상자에 위아래 여백이 이미 들어 있어서다 — 0으로 두면 그 여백만큼 떠 보인다.
            VStack(alignment: .leading, spacing: -Spacing.xs) {
                Text(item.title)
                    // 제목이 이 줄의 머리다 — 시각보다 크고 굵게.
                    //
                    // 폭이 위젯의 절반뿐이라 긴 제목은 잘린다. `minimumScaleFactor`로
                    // 폭 안에서 줄여 담되, 너무 작아지기 전에 멈춘다.
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    // 완료된 할일은 한 단계 물러난다 — 월 셀 칩과 같은 규칙.
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                Text(WidgetItemListView.timeText(for: item, calendar: calendar))
                    // 시각은 보조 정보라 제목보다 두 단계 아래로 둔다.
                    .font(.caption2)
                    // 마감이 지난 할일은 시각을 빨갛게 — 오늘 마감은 시각이 지나도 목록에
                    // 남는데(→ `UpcomingItemPicker`) 평소 색이면 "아직 안 지났다"로 읽힌다.
                    // 평소엔 `.secondary`가 이 크기에서 너무 흐려 본문색을 직접 낮춰 쓴다.
                    .foregroundStyle(
                        item.isOverdue(now: now) ? Color.red : Color.primary.opacity(0.65)
                    )
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.zero)
        }
    }

    /// 항목 앞 마커 — 종류마다 다른 모양으로, 색은 캘린더/미리알림 리스트 색.
    @ViewBuilder
    private func marker(for item: WidgetCalendarItem) -> some View {
        let color = WidgetCalendarTheme.color(of: item)
        switch item.kind {
        case .reminder:
            // 스크린샷의 큰 동그라미 — 목록에서는 셀 칩(4pt)보다 크게 그린다.
            // 우선순위·완료는 채운 원으로 갈린다(월 셀 칩과 같은 규칙).
            if item.isCompleted || item.isHighPriority {
                Circle()
                    .fill(color)
                    .frame(width: Self.markerDiameter, height: Self.markerDiameter)
            } else {
                Circle()
                    .strokeBorder(color, lineWidth: Self.markerLineWidth)
                    .frame(width: Self.markerDiameter, height: Self.markerDiameter)
            }
        case .allDayEvent:
            // 종일은 **꽉 채운** 사각 — 셀 칩에서 종일이 채워진 칩인 것과 같은 뜻.
            RoundedRectangle(cornerRadius: WidgetCalendarTheme.chipCornerRadius)
                .fill(color)
                .frame(width: Self.markerDiameter, height: Self.markerDiameter)
        case .timedEvent:
            // 시간 일정은 세로 막대 — 두 줄 높이에 맞춰 세운다.
            RoundedRectangle(cornerRadius: WidgetCalendarTheme.markerBarWidth / 2)
                .fill(color)
                .frame(width: WidgetCalendarTheme.markerBarWidth, height: Self.barMarkerHeight)
                // 원·사각 마커와 **같은 자리**를 차지하게 폭을 맞춘다 — 안 맞추면 종류가
                // 섞인 목록에서 제목 시작점이 줄마다 흔들린다.
                .frame(width: Self.markerDiameter)
        }
    }

    /// 목록 마커의 지름 — 글자와 함께 줄인다. 글자만 작아지면 마커가 상대적으로 커져
    /// 목록에서 동그라미가 먼저 읽힌다.
    ///
    /// 간격이 아니라 **도형 크기**라 `Spacing` 토큰이 아니라 여기 둔다
    /// (`WidgetCalendarTheme`의 마커 크기와 같은 성격).
    /// 줄 하나가 쓰는 높이 — 제목 + 시각 두 줄에 최소한의 여유만.
    ///
    /// 칸(`slot`)을 꽉 채우지 않는 이유는 남는 높이가 줄 **사이**로 흩어져 목록이
    /// 성기게 보이기 때문이다. 이 값으로 눌러 담고 남는 건 아래에 모은다.
    private static let rowContentHeight: CGFloat = 32
    /// 줄 사이 간격.
    private static let rowSpacing: CGFloat = Spacing.xxs

    private static let markerDiameter: CGFloat = 16
    /// 빈 원의 테두리 두께 — 지름이 커진 만큼 같이 올린다. 얇으면 큰 원이 흐려 보인다.
    private static let markerLineWidth: CGFloat = 1.8
    /// 시간 일정 세로 막대의 높이 — 제목+시각 두 줄에 걸친다.
    private static let barMarkerHeight: CGFloat = 20

    // MARK: - 시각 표기

    /// 항목 아래 회색 줄 — "8월 13일 오후 12:25" / 종일은 "8월 15일 하루 종일".
    ///
    /// 날짜를 항상 붙인다. 목록이 오늘 것으로 끝나지 않고 내일·모레로 이어지므로
    /// (→ `UpcomingItemPicker`), 시각만 있으면 그게 오늘 19시인지 내일 19시인지 알 수 없다.
    ///
    /// 종일 문구는 **인앱 일정 행과 같은 키**를 쓴다(→ `ScheduleTimeText`) — 같은 뜻에
    /// 번역이 둘로 갈리면 앱 안에서 "종일"과 "하루 종일"이 섞여 나온다.
    ///
    /// 다만 시각은 `ScheduleTimeText`를 그대로 쓰지 않고 **시작 시각만** 쓴다. 저쪽은
    /// 인앱 일정 행용이라 "오후 7:00 - 오후 9:00"처럼 범위를 돌려주는데, 여기는 폭이
    /// 위젯의 절반뿐이라 잘린다. 게다가 미리알림은 `start == end`라 그대로 쓰면
    /// "오후 7:00 - 오후 7:00"이 된다.
    ///
    /// 포맷 자체(12/24시간·오전오후)는 `ScheduleTimeText`와 같은 `j` 템플릿이라 갈리지 않는다.
    static func timeText(for item: WidgetCalendarItem, calendar: Calendar = .current) -> String {
        // 종일 일정·날짜만 지정한 할일은 시각이 없어 줄이 날짜뿐이다 — "하루 종일" 대신
        // 요일을 붙여 빈자리를 정보로 채운다("8월 15일 토요일"). 시각 분기로 흘리면 날짜만
        // 지정한 할일은 EventKit이 준 자정이 "0:00"으로 찍힌다(실기기 확인).
        // 약칭(E)이 아니라 전체 요일명(EEEE)이다 — 시각 일정의 시각 자리에 서는 줄이라
        // "(토)"로는 너무 짧아 잘린 것처럼 보인다. 순서·구두점은 로케일이 정하도록
        // 한 템플릿에 담는다(영어는 요일이 앞: "Saturday, Aug 15").
        guard !item.displaysAsDateOnly else {
            return formatted(item.start, template: "MMMdEEEE", calendar: calendar)
        }
        let day = formatted(item.start, template: "MMMd", calendar: calendar)
        // `j`(기기 12/24시간 설정 추종)가 아니라 `H` — "오전/오후" 접두가 날짜와 겹치면
        // 줄이 길어져 위젯 절반 폭에서 잘린다. 24시간 고정("22:00")이 짧고 어느 로케일에서도 같다.
        let time = formatted(item.start, template: "Hmm", calendar: calendar)
        return "\(day) \(time)"
    }

    private static func formatted(_ date: Date, template: String, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}
