//
//  MemoLiveActivityAttributes.swift
//  cue / Shared
//

import ActivityKit
import Foundation

/// 메모 라이브 액티비티의 attributes.
///
/// 텍스트·색 모두 사용자가 활성 중에도 수정할 수 있으므로 ContentState에 둔다 — 수정 시
/// `update`로 부드럽게 반영(재시작 깜빡임 없음). `startedAt`은 게시 시점 추적용 식별 값.
///
/// 시간 흐름과 무관 — `staleDate`는 service 구현에서 nil(사용자 동작에서만 갱신).
struct MemoLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        /// 카드 가운데 큰 텍스트. use case가 빈 값 검증·길이 제한을 마친 값.
        var text: String
        /// 카드 배경 색("#RRGGBB"). 파싱 실패 시 위젯이 시스템 accent로 폴백.
        var colorHex: String
    }

    let startedAt: Date
}
