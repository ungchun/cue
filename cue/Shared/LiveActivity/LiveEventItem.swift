//
//  LiveEventItem.swift
//  cue / Domain
//

import Foundation

/// 라이브 액티비티에 표시할 캘린더 이벤트 한 건 — Domain `CalendarEvent`의 표시용 스냅샷.
///
/// `startDate`·`endDate`는 시스템 Live Activity의 `Text(_:style: .relative)` /
/// `Text(timerInterval:)`이 매 프레임 자동 갱신해주므로 그대로 들고 가면 매초 update가
/// 필요 없다. `calendarColorHex`는 EventKit이 주는 raw hex를 그대로 — 디자인 시스템
/// 컬러 규칙의 **외부 데이터 표현 예외** 항목이라 hex 통과를 허용한다.
struct LiveEventItem: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarColorHex: String?
}
