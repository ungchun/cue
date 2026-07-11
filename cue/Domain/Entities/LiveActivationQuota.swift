//
//  LiveActivationQuota.swift
//  cue / Domain
//

import Foundation

/// 무료 사용자의 라이브 활성화(켜기·새로고침) 하루 사용량 스냅샷.
/// `dayKey`("2026-7-11")가 오늘과 다르면 사용량은 무효 — 소비 시점에 리셋된다.
struct LiveActivationQuota: Codable, Equatable, Sendable {
    var dayKey: String
    var used: Int

    static let empty = LiveActivationQuota(dayKey: "", used: 0)
}

/// 활성화 시도 판정 — 뷰가 토스트 문구를 정하는 근거.
/// `.allowed(remaining:)`이면 시작하고 "1/2"·"0/2"식 잔여 표기, `.denied`면 Premium 안내.
enum LiveActivationVerdict: Equatable, Sendable {
    case allowed(remaining: Int)
    case denied
    /// Premium — 한도 없음. 뷰는 기존 라이브/새로고침 토스트를 유지한다.
    case unlimited
}
