//
//  EventEditOutcome.swift
//  cue / Presentation
//

import Foundation

/// 이벤트 편집 시트 종료 결과 — 호출처(ViewModel)가 분석 이벤트
/// (event_created/updated/deleted) 판별에 쓴다. 취소·기타는 전부 `.canceled`.
enum EventEditOutcome: Equatable, Sendable {
    case saved
    case deleted
    case canceled
}
