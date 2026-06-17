//
//  StartReminderLiveActivityUseCase.swift
//  cue / Domain
//

import Foundation

/// 미리알림 리스트 스냅샷을 라이브 액티비티로 게시.
///
/// 위젯은 앞 6개만 보여주지만, ContentState엔 `storageLimit`(20)개까지 싣는다 — LA에서 항목을
/// 체크(완료)해 빠졌을 때 다음 항목이 빈 칸을 즉시 메우게(backfill) 하기 위함. 익스텐션엔 표시
/// 밖 항목의 데이터가 없으면 빈자리를 못 채우기 때문이다. `storageLimit`을 넘는 개수는
/// `remaining`으로만 집계한다(카운트 표시용). cap 값은 ContentState ~4KB 한도 안의 보수적 깊이.
/// 잘라내기 기준은 **입력 배열 순서** — 호출처에서 시간/중요도 순으로 미리 정렬한다.
struct StartReminderLiveActivityUseCase: Sendable {
    let service: any LiveActivityService

    static let storageLimit = 20

    /// - Parameter listColors: 리스트 ID → 색(`"#RRGGBB"`) 매핑. 각 항목의 동그라미 색을
    ///   자기 리스트 색으로 채운다 — 매핑에 없으면 `nil`(위젯에서 시스템 색 폴백).
    func callAsFunction(
        listTitle: String,
        reminders: [Reminder],
        listColors: [String: String],
        now: Date = .now
    ) async throws {
        let visible = reminders.prefix(Self.storageLimit).map {
            LiveReminderItem(id: $0.id, title: $0.title, colorHex: listColors[$0.listID])
        }
        let remaining = max(0, reminders.count - Self.storageLimit)
        try await service.startReminder(
            listTitle: listTitle,
            items: Array(visible),
            remaining: remaining,
            todayCount: Self.todayCount(reminders, now: now)
        )
    }

    /// Dynamic Island 주간 캘린더 스트립의 "오늘 할일" 카운트.
    /// 포함: 미완료 AND (마감일 없음 OR 마감일이 오늘). 제외: 완료, 마감 지남(overdue), 미래 마감.
    static func todayCount(_ reminders: [Reminder], now: Date) -> Int {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        return reminders.filter { reminder in
            guard !reminder.isCompleted else { return false }
            guard let due = reminder.dueDate else { return true }   // 마감 미지정 → 카운트
            return due >= todayStart && due < tomorrowStart          // 오늘 마감만(지남·미래 제외)
        }.count
    }
}
