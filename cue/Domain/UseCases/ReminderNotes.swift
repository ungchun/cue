//
//  ReminderNotes.swift
//  cue / Domain
//

import Foundation

/// 미리 알림 메모 정규화 규칙 — 추가·수정 UseCase가 공유한다.
/// 공백뿐인 메모는 "메모 없음"(nil)으로 본다. 빈 메모를 저장소마다 다르게
/// 다루지 않도록 한 곳에 모은다.
enum ReminderNotes {
    /// 앞뒤 공백을 제거하고, 비어 있으면 nil로 바꾼다.
    static func normalized(_ notes: String?) -> String? {
        let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty ?? true) ? nil : trimmed
    }
}
