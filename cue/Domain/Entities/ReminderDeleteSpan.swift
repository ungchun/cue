//
//  ReminderDeleteSpan.swift
//  cue / Domain
//

/// 반복 할일 삭제 범위 — 미리 알림 앱의 "이 미리 알림만 삭제 / 이후 모든 미리 알림 삭제"와 같다.
/// 반복이 아닌 항목은 두 범위 모두 항목 전체를 지운다.
enum ReminderDeleteSpan: Sendable {
    /// 이번 회차만 — 항목은 남고 다음 회차로 넘어간다(완료 기록은 남기지 않는다).
    case thisOccurrence
    /// 이번 회차부터 이후 전부 — 항목 자체를 지운다. 이미 완료된 지난 회차 기록은 남는다.
    case futureOccurrences
}
