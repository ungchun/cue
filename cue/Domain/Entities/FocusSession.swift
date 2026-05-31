//
//  FocusSession.swift
//  cue / Domain
//

import Foundation

/// 사용자가 저장해 두는 집중 세션 프리셋 — 이름 + 설정(`FocusSettings`) 조합.
///
/// "독서하기"·"운동" 같은 이름으로 자주 쓰는 시간·반복 패턴을 묶어두고, 시작 시 목록에서
/// 골라 그대로 돌린다. ViewModel은 이 배열을 들고 있다가 선택된 항목의 `settings`를
/// 세션 상태머신(`FocusSessionViewModel`)에 넘겨 실제 타이머를 돌린다.
struct FocusSession: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var settings: FocusSettings
}
