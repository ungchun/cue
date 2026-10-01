//
//  RefreshLiveActivityDecision.swift
//  cue / Domain
//

import Foundation

/// 단축어 자동화(「24시간 사용하기」)가 라이브를 새로 게시할 수 있는지 판단한다.
///
/// 판단을 `AppIntent`에서 떼어낸 이유는 **검증 때문**이다. 인텐트의 `perform()`은 앱이 꺼진
/// 상태에서 백그라운드로 도는 경로라 실기기에서 재현·관찰이 어렵다. 틀린 판단이 하루 세 번
/// 조용히 반복되는 걸 막으려면 규칙만이라도 화면 없이 검증할 수 있어야 한다.
/// 무엇을 새로고침할지(살아있는 종류)는 `RefreshLiveActivityRunner`가 정한다.
enum RefreshLiveActivityDecision {

    /// 메모를 게시할 수 있는가 — 내용이 있어야 한다.
    ///
    /// 빈 메모로 시도하면 `StartMemoLiveActivityUseCase`가 throw하고, 자동 경로라 그 실패가
    /// 조용히 삼켜져 사용자에겐 "단축어가 안 먹는다"로만 보인다.
    static func canPublishMemo(_ memo: Memo) -> Bool {
        !memo.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
