//
//  MonthEventsSnapshot.swift
//  cue / Domain
//

import Foundation

/// 월 캘린더의 달별 일정 스냅샷 — `EventsSnapshot`과 같은 첫 페인트용 캐시.
/// 키는 달 1일 자정이고 값은 그 달 범위로 조회한 일정(숨김 필터 전 원본)이다.
/// 숨김 필터를 저장 후에 적용해야 캘린더 선택 변경이 캐시 재조회 없이 반영된다.
/// `Date` 키 딕셔너리는 JSON에서 [키, 값, 키, 값…] 배열로 인코딩되며 왕복 시 보존된다.
struct MonthEventsSnapshot: Equatable, Sendable, Codable {
    var months: [Date: [CalendarEvent]]
}
