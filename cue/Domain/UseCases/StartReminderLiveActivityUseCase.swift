//
//  StartReminderLiveActivityUseCase.swift
//  cue / Domain
//

/// 미리알림 리스트 스냅샷을 라이브 액티비티로 게시.
///
/// 표시 한도(`maxVisibleItems` = 6)을 넘는 항목은 잘라 사용하고 나머지 개수만 `remaining`에
/// 담아 service에 넘긴다. 잘라내기 기준은 **입력 배열 순서** — 호출처에서 시간/중요도 순으로
/// 미리 정렬한다. cap 값은 lock screen 시각 안정성 + ContentState ~4KB 한도를 함께 고려한
/// Apple 권장 범위 안의 값.
struct StartReminderLiveActivityUseCase: Sendable {
    let service: any LiveActivityService

    static let maxVisibleItems = 6

    func callAsFunction(listTitle: String, reminders: [Reminder]) async throws {
        let visible = reminders.prefix(Self.maxVisibleItems).map {
            LiveReminderItem(id: $0.id, title: $0.title)
        }
        let remaining = max(0, reminders.count - Self.maxVisibleItems)
        try await service.startReminder(
            listTitle: listTitle,
            items: Array(visible),
            remaining: remaining
        )
    }
}
