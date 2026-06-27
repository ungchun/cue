//
//  Memo.swift
//  cue / Domain
//

import Foundation

/// 사용자가 잠금화면·Dynamic Island에 큰 텍스트로 띄워두는 단일 메모.
///
/// cue 컨셉의 핵심 — "지금 잊으면 안 되는 하나"를 한 문장으로 적어 신호처럼 띄운다.
/// 메모는 앱당 하나만 다룬다(목록 아님). `colorHex`는 라이브 액티비티 카드 배경색에
/// 적용된다. 비어 있으면 라이브 액티비티를 띄울 수 없다(시작 use case에서 검증).
struct Memo: Codable, Equatable, Sendable {
    var text: String
    /// "#RRGGBB" 형식의 사용자 지정 카드 색. 파싱 실패 시 위젯이 시스템 accent로 폴백.
    var colorHex: String

    /// 첫 실행·미저장 상태의 기본값 — 빈 텍스트 + 검은 카드(위젯이 흰 텍스트라 검정/하양).
    static let `default` = Memo(text: "", colorHex: "#000000")
}
