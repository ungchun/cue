//
//  ReviewPromptState.swift
//  cue / Domain
//

import Foundation

/// 리뷰 요청 판정에 쓰는 누적 상태.
///
/// `AppSettings`에 얹지 않고 **독립 저장소**로 둔다 — `AppSettings`는 통째로 읽고 쓰는 블롭이라
/// 이미 두 writer(`SettingsViewModel`·`ReconcilePremiumSettingsUseCase`)가 각자 직렬화 체인으로
/// 자기들끼리만 경합을 막고 있다. 라이브 버튼에서 오는 세 번째 writer가 끼어들면 fetch-modify-save가
/// 인터리브돼 프리미엄 복구 설정이 유실되거나, 요청 기록이 날아가 리뷰가 두 번 뜰 수 있다.
/// 관심사도 설정이 아니므로 `LiveActivationQuota`처럼 자기 키에 따로 산다.
struct ReviewPromptState: Codable, Equatable, Sendable {
    /// 라이브를 실제로 띄운 **서로 다른 날**의 누적 수. 하루에 몇 번 띄우든 1만 오른다.
    var usageDayCount: Int
    /// 마지막으로 센 날의 키. 같은 날 재게시가 중복으로 세지 않게 하는 기준.
    var lastDayKey: String?
    /// 이미 리뷰를 요청한 문턱들 — 같은 문턱이 두 번 뜨지 않게 한다.
    var promptedThresholds: Set<Int>

    init(usageDayCount: Int = 0, lastDayKey: String? = nil, promptedThresholds: Set<Int> = []) {
        self.usageDayCount = usageDayCount
        self.lastDayKey = lastDayKey
        self.promptedThresholds = promptedThresholds
    }

    static let empty = ReviewPromptState()
}

extension ReviewPromptState {
    /// 전방 호환 디코딩 — 필드가 늘어도 옛 저장본이 통째로 버려지지 않게(`AppSettings` 전례).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usageDayCount = try container.decodeIfPresent(Int.self, forKey: .usageDayCount) ?? 0
        lastDayKey = try container.decodeIfPresent(String.self, forKey: .lastDayKey)
        promptedThresholds = try container.decodeIfPresent(Set<Int>.self, forKey: .promptedThresholds) ?? []
    }
}
