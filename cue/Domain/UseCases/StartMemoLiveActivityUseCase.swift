//
//  StartMemoLiveActivityUseCase.swift
//  cue / Domain
//

import Foundation

/// 메모를 라이브 액티비티로 게시.
///
/// 텍스트가 비어 있으면(공백만 포함 포함) 게시하지 않고 `DomainError.validation`을 던진다 —
/// 빈 신호는 의미가 없다. 호출처(ViewModel)는 빈 텍스트일 때 토글 버튼 자체를 비활성화해
/// 이 경로가 평상시엔 오지 않게 한다(검증은 마지막 방어선).
///
/// 긴 메모는 `maxTextLength`로 잘라 싣는다 — ActivityKit ContentState ~4KB 한도 안전 마진 +
/// 큰 폰트 카드에 한 문장이 들어갈 분량.
struct StartMemoLiveActivityUseCase: Sendable {
    let service: any LiveActivityService

    /// 카드에 싣는 최대 글자 수. 큰 텍스트라 위젯에서 축소·줄임되며, 이 값은 저장/전송
    /// 안전 상한이다.
    static let maxTextLength = 120

    func callAsFunction(_ memo: Memo) async throws {
        let trimmed = memo.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.validation(String(localized: "Please enter a memo."))
        }
        let capped = String(trimmed.prefix(Self.maxTextLength))
        try await service.startMemo(text: capped, colorHex: memo.colorHex, textColorHex: memo.textColorHex)
    }
}
