//
//  LiveScheduleDay.swift
//  cue / Shared
//

import Foundation

/// 일정 라이브 액티비티의 하루 묶음 — 날짜 라벨 + 그날 이벤트들.
///
/// `label`은 게시 시점에 미리 계산해 박는다(오늘/내일/모레 또는 로케일별 날짜 표기(한국어 `"7월 28일"`)). 위젯이
/// 날짜 연산을 하지 않게 해 단순화 — 날이 바뀌어 라벨이 낡으면 앱이 다음 갱신 때 새로 채운다
/// (today/tomorrow 시절과 동일한 staleness 정책). 표시 가능한 만큼만 위젯이 잘라 그린다.
struct LiveScheduleDay: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let label: String
    let events: [LiveEventItem]
}
