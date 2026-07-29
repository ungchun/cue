//
//  WidgetCalendarTheme.swift
//  cueLiveActivity
//
//  홈 화면 캘린더 위젯 4종이 공유하는 색·치수·포맷 규칙.
//  값을 한곳에 모아 월 위젯과 타임라인 위젯의 눈금·거터가 어긋나지 않게 한다.
//

import SwiftUI
import WidgetKit

enum WidgetCalendarTheme {

    // MARK: - 색
    //
    // 항목 색(캘린더·미리알림 리스트 색)은 EventKit이 주는 외부 데이터라 hex를 통과시킨다.
    // 그 외 모든 색은 시스템 시맨틱 컬러 — 라이트/다크는 시스템이 알아서 뒤집는다.

    /// 항목 색. 색이 없거나 파싱 실패면 시스템 accent.
    static func color(of item: WidgetCalendarItem) -> Color {
        guard let hex = item.colorHex, let parsed = Color(hex: hex) else { return .accentColor }
        return parsed
    }

    /// 캘린더 색으로 **꽉 채운** 칩(종일 일정) 위 글자색 — 배경 밝기로 갈린다.
    static func filledChipForeground(of item: WidgetCalendarItem) -> Color {
        WidgetChipContrast.prefersDarkText(onHex: item.colorHex) ? .black : .white
    }

    /// 월 셀에서 시간 일정 칩의 배경 농도 — 캘린더 색을 옅게 깔아 종일 칩과 구분한다.
    /// 다크 배경에서 0.2 언저리는 사실상 검정과 구분되지 않아 조금 올려 잡는다.
    static let softBackgroundOpacity: Double = 0.32

    /// 시간표 블록 배경 농도 — 월 칩보다 진하다. 시간표에서는 배경이 "이 시간대를 점유한다"는
    /// 정보 자체라 옅으면 눈금선에 묻힌다.
    ///
    /// 레퍼런스(캘린더 앱)와 같은 블록의 픽셀을 재보니 우리 쪽이 한 단계 밝았다
    /// (RGB 60·73·87 대 50·57·65) — 배경이 뜨면 그 위 제목의 대비가 깎인다.
    static let blockBackgroundOpacity: Double = 0.32

    /// 제목을 그릴 자리가 없어 **색 막대로만** 남는 블록의 배경 농도.
    /// 옅은 값 그대로 두면 존재 자체가 안 보여, 글자가 빠진 만큼 진하게 보상한다.
    static let barOnlyBackgroundOpacity: Double = 0.65

    /// 시간축 눈금·구분선 색. 시스템 구분선 계열이라 라이트/다크 모두 자동 대응한다.
    static let gridLine: Color = .primary.opacity(0.18)

    /// 눈금·구분선 두께. `Divider`는 자체 여백이 붙어 눈금 위치가 어긋나므로 직접 그린다 —
    /// 월 격자와 시간표가 같은 값을 써야 두 위젯이 나란히 놓였을 때 선 굵기가 튀지 않는다.
    static let hairline: CGFloat = 0.5

    /// 요일 글자색 — 일요일·공휴일 빨강, 토요일 파랑, 평일 본문색.
    /// `weekday`는 1=일 … 7=토.
    static func weekdayColor(_ weekday: Int, isHoliday: Bool = false) -> Color {
        if weekday == 1 || isHoliday { return .red }
        if weekday == 7 { return .blue }
        return .primary
    }

    // MARK: - 치수
    //
    // 간격은 `Spacing` 토큰. 아래는 간격이 아니라 **도형 크기**라 실측값을 쓴다
    // (LA 위젯의 오늘 밑줄·일정 막대와 같은 성격).

    /// 시간축 라벨이 들어가는 왼쪽 거터 폭. 헤더의 주차 배지도 같은 폭을 써서 세로로 정렬된다.
    static let gutterWidth: CGFloat = 22
    /// 항목 앞 마커(원)의 지름.
    static let markerSize: CGFloat = 5
    /// 시간 일정 마커 막대의 폭 — 세로로 길게 세우므로 폭은 얇게.
    static let markerBarWidth: CGFloat = 3
    /// 막대 위아래 인셋. 칩 높이를 꽉 채우면 막대가 글자보다 길어 보여 칩이 무거워진다 —
    /// 보이는 글자 높이 정도로 짧게 세운다.
    static let markerBarInset: CGFloat = 4
    /// 칩·블록 모서리. 레퍼런스는 거의 각진 사각이라 작게 잡는다.
    static let chipCornerRadius: CGFloat = 2
    /// 오늘 날짜 밑줄 바 두께 — LA 월간 캘린더와 같은 표현.
    static let todayUnderlineHeight: CGFloat = 2

    // MARK: - 타임라인 블록 임계값
    //
    // 24시간을 위젯 한 장에 담으면 30분 일정의 높이가 4pt 남짓이다. 거기에 제목을 밀어 넣으면
    // 글자가 블록을 뚫고 옆 열까지 번진다(실제로 그렇게 깨졌다). 그래서 **들어갈 자리가 있을
    // 때만** 제목을, 더 좁으면 마커까지 뺀다. 자리가 없으면 색 막대만 남기고 정보는 포기한다.

    /// 블록이 시각적으로 존재하려면 최소 이 높이는 차지한다.
    static let minimumBlockHeight: CGFloat = 3
    /// 이 높이 이상이어야 제목 한 줄을 그린다.
    ///
    /// caption2 줄높이(13.1)가 아니라 그보다 낮게 잡는다 — 줄높이에는 위아래 리딩(여백)이
    /// 포함돼 있어 글리프 자체는 더 작다. 시간축이 24시간을 265pt에 담으므로 1시간 =
    /// 11pt인데, 줄높이를 그대로 기준 삼으면 **한 시간짜리 일정이 전부 색 막대로만** 남는다.
    /// 살짝 잘리더라도 잘리는 쪽은 디센더 영역이고, 바깥 `.clipped()`가 칸 밖 침범을 막는다.
    static let titleHeightThreshold: CGFloat = 10
    /// 이 폭 이상이어야 제목을 그린다 — 더 좁으면 말줄임표만 남아 의미가 없다.
    static let titleWidthThreshold: CGFloat = 30
    /// 이 폭 이상이어야 제목 앞 마커까지 그린다.
    static let markerWidthThreshold: CGFloat = 46
    /// 겹침이 이보다 잘게 쪼개지면 블록이 알아볼 수 없어진다 — 초과분은 `+N`으로 돌린다.
    static let maximumOverlapColumns = 4

    // MARK: - 포맷

    /// 헤더의 월 이름만 — ko "7월" / en "July".
    static func monthName(for date: Date, calendar: Calendar = .current) -> String {
        formatted(date, template: "MMMM", calendar: calendar)
    }

    /// 헤더의 연도만 — ko "2026년" / en "2026".
    static func yearName(for date: Date, calendar: Calendar = .current) -> String {
        formatted(date, template: "y", calendar: calendar)
    }

    private static func formatted(_ date: Date, template: String, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    /// 1일 위젯 헤더의 요일 전체 이름("월요일" / "Monday").
    static func weekdayName(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter.string(from: date)
    }

    /// 3일 위젯 열 머리의 짧은 요일("월" / "Mon").
    static func shortWeekdayName(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }
}

// MARK: - 위젯 배경

extension View {
    /// 캘린더 위젯의 배경.
    ///
    /// `Color(.systemBackground)`가 아니라 순수 검정/흰색을 쓴다. 다크 모드에서
    /// `.systemBackground`는 완전한 검정이 아니라 살짝 뜬 회색이라, 그 위에 캘린더 색 칩이
    /// 깔리면 카드 전체가 부옇게 밝아진다(실기기에서 레퍼런스와 나란히 놓고 확인).
    /// 격자가 배경 그 자체인 화면이라 배경은 최대한 뒤로 물러나 있어야 한다.
    ///
    /// 같은 색을 **두 번** 칠한다. `containerBackground`만 주면 시스템이 그 위에 위젯 재질을
    /// 얹어 상단이 하단보다 밝게 뜬다(실기기에서 확인 — 코드엔 그라데이션이 없다).
    /// 콘텐츠 바로 뒤에 단색을 한 겹 더 깔면 그 재질이 가려져 위아래가 균일해진다.
    ///
    /// 루트에서 따로 클립하지 않는다 — 시스템이 이미 위젯을 둥근 사각으로 잘라낸다.
    /// 여기서 한 겹 더 깎으면 넘친 콘텐츠까지 같이 숨겨져, 레이아웃이 넘치고 있다는
    /// 사실 자체가 보이지 않는다(마지막 주가 사라진 걸 하단 여백으로 오진하게 만들었다).
    func calendarWidgetBackground(_ colorScheme: ColorScheme) -> some View {
        let color = colorScheme == .dark ? Color.black : Color.white
        return frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(color)
            .containerBackground(for: .widget) { color }
    }
}
