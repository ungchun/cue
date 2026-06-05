//
//  StartScheduleLiveActivityUseCase.swift
//  cue / Domain
//

/// 오늘·내일 일정 스냅샷을 라이브 액티비티로 게시.
///
/// `CalendarEvent`(Domain) → `LiveEventItem`(표시용 DTO) 매핑은 schema migration 안전성과
/// ContentState 크기 둘 다를 위해 표시 필드만 추출.
struct StartScheduleLiveActivityUseCase: Sendable {
    let service: any LiveActivityService

    func callAsFunction(
        today: [CalendarEvent],
        tomorrow: [CalendarEvent]
    ) async throws {
        try await service.startSchedule(
            today: today.map(Self.map),
            tomorrow: tomorrow.map(Self.map)
        )
    }

    /// 표시용 매핑 — id/title/시각/캘린더 색만. all-day 여부는 startDate==endDate로 추론하거나
    /// 추후 ContentState 확장 시 추가.
    private static func map(_ event: CalendarEvent) -> LiveEventItem {
        LiveEventItem(
            id: event.id,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            calendarColorHex: event.calendarColorHex
        )
    }
}
