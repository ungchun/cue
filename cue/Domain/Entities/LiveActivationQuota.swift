//
//  LiveActivationQuota.swift
//  cue / Domain
//

import Foundation

/// 무료 사용자의 라이브 활성화(켜기·새로고침) 하루 사용량 스냅샷.
/// `dayKey`("2026-7-11")가 오늘과 다르면 사용량은 무효 — 소비 시점에 리셋된다.
/// `firstDayKey`는 생애 최초 사용일 — 그날만 한도 2, 이후는 매일 1(맛보기 후 Premium 유도).
struct LiveActivationQuota: Codable, Equatable, Sendable {
    var dayKey: String
    var used: Int
    /// 최초 사용일. nil이면 아직 한 번도 소비한 적 없음 — 첫 소비 날이 기록된다.
    var firstDayKey: String?

    init(dayKey: String, used: Int, firstDayKey: String? = nil) {
        self.dayKey = dayKey
        self.used = used
        self.firstDayKey = firstDayKey
    }

    static let empty = LiveActivationQuota(dayKey: "", used: 0)
}

extension LiveActivationQuota {
    /// 전방 호환 디코딩 — `firstDayKey`가 없던 옛 저장본은 nil로 채운다(다음 소비 날이 최초 사용일).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dayKey = try container.decodeIfPresent(String.self, forKey: .dayKey) ?? ""
        used = try container.decodeIfPresent(Int.self, forKey: .used) ?? 0
        firstDayKey = try container.decodeIfPresent(String.self, forKey: .firstDayKey)
    }
}

/// 활성화 시도 판정 — 뷰가 토스트 문구를 정하는 근거.
/// `.allowed(remaining:limit:)`이면 시작하고 "1/2"·"0/1"식 잔여/한도 표기, `.denied`면 Premium 안내.
enum LiveActivationVerdict: Equatable, Sendable {
    case allowed(remaining: Int, limit: Int)
    case denied
    /// Premium — 한도 없음. 뷰는 기존 라이브/새로고침 토스트를 유지한다.
    case unlimited
}
