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
    /// "#RRGGBB" 형식의 사용자 지정 카드 배경 색. 파싱 실패 시 위젯이 시스템 accent로 폴백.
    var colorHex: String
    /// "#RRGGBB" 형식의 사용자 지정 카드 글자(폰트) 색. 파싱 실패 시 위젯이 흰색으로 폴백.
    var textColorHex: String

    /// 명시적 이니셜라이저 — `textColorHex`에 기본값을 둬 옛 호출처(`Memo(text:colorHex:)`)가
    /// 그대로 컴파일되게 한다(필드 추가의 cascade 최소화).
    init(text: String, colorHex: String, textColorHex: String = "#FFFFFF") {
        self.text = text
        self.colorHex = colorHex
        self.textColorHex = textColorHex
    }

    /// 첫 실행·미저장 상태의 기본값 — 빈 텍스트 + 검은 카드 + 흰 글자.
    static let `default` = Memo(text: "", colorHex: "#000000", textColorHex: "#FFFFFF")
}

extension Memo {
    /// 전방 호환 디코딩 — 저장 당시 없던 키(`textColorHex`)는 기본값으로 채운다.
    /// (필드를 추가해도 기존 사용자의 저장본이 통째로 버려지지 않도록 — `AppSettings`와 같은 방식.)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Memo.default
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? fallback.text
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? fallback.colorHex
        textColorHex = try container.decodeIfPresent(String.self, forKey: .textColorHex)
            ?? fallback.textColorHex
    }
}
