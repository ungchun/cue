//
//  FocusSession.swift
//  cue / Domain
//

import Foundation

/// 사용자가 저장해 두는 집중 세션 프리셋 — 이름 + 설정(`FocusSettings`) + 표시 색 묶음.
///
/// "독서하기"·"운동" 같은 이름으로 자주 쓰는 시간·반복 패턴을 묶어두고, 시작 시 목록에서
/// 골라 그대로 돌린다. `colorHex`는 시트 행 캡슐·메인 화면 타이틀·ring 진행 색에
/// 일관되게 적용된다.
struct FocusSession: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var settings: FocusSettings
    /// "#RRGGBB" 형식의 사용자 지정 색. 비어 있거나 파싱 실패 시 뷰가 시스템 회색으로 폴백.
    var colorHex: String
}
