//
//  EventOccurrenceRef.swift
//  cue / Presentation
//

import Foundation

/// 이벤트 상세 시트가 열 "그 회차" — 이벤트 ID + 회차 시작 시각.
///
/// 반복 이벤트는 모든 회차가 같은 `eventIdentifier`를 공유해서 ID만으로 찾으면
/// EventKit이 첫 회차를 돌려준다(5번째 회차를 탭했는데 첫 회차를 수정·삭제하던 버그).
/// 시작 시각을 함께 실어 시트가 탭한 회차를 정확히 찾게 한다(EventOccurrenceLocator).
struct EventOccurrenceRef: Hashable, Identifiable, Sendable {
    let eventID: String
    let occurrenceStart: Date

    /// `.sheet(item:)` 식별자 — 같은 시리즈라도 회차가 다르면 다른 시트.
    var id: String { "\(eventID)@\(occurrenceStart.timeIntervalSinceReferenceDate)" }
}
