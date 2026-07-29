//
//  RefreshLiveActivityDecision.swift
//  cue / Domain
//

import Foundation

/// 단축어 자동화(「24시간 사용하기」)가 라이브를 되살릴지 판단한다.
///
/// 라이브 액티비티는 시스템이 **8시간 뒤 강제 종료**한다. 그래서 사용자가 단축어 앱에
/// 8시간 간격 자동화를 걸어두고, 그 자동화가 이 판단을 거쳐 라이브를 다시 게시한다.
///
/// **기준은 설정이 아니라 "사용자가 켜둔 채로 두었는가"** 다. 「라이브 항상 표시」는
/// *앱을 열 때* 자동으로 띄우는 설정이라 목적이 다르다 — 그걸 조건으로 삼으면 자동화만
/// 쓰려는 사용자가 영문도 모른 채 아무 동작도 못 얻는다(실제로 그렇게 막혔다).
/// 대신 `LiveActivityIntentRecord`가 "켰고 아직 직접 끄지 않았다"를 기록한다.
///
/// 판단을 `AppIntent`에서 떼어낸 이유는 **검증 때문**이다. 인텐트의 `perform()`은 앱이 꺼진
/// 상태에서 백그라운드로 도는 경로라 실기기에서 재현·관찰이 어렵다. 틀린 판단이 하루 세 번
/// 조용히 반복되는 걸 막으려면 규칙만이라도 화면 없이 검증할 수 있어야 한다.
enum RefreshLiveActivityDecision {

    /// 지금 이 종류의 라이브를 다시 게시해야 하는가.
    ///
    /// - Parameters:
    ///   - isPremium: 호출 **시점**의 구독 여부. 설정에 남은 값이 아니라 실제 엔타이틀먼트다.
    ///   - kind: 되살릴 대상.
    ///   - wanted: 사용자가 켜둔 채로 둔 종류들(`LiveActivityIntentRecord.wanted()`).
    static func shouldRepublish(
        isPremium: Bool,
        kind: LiveActivityKind,
        wanted: Set<LiveActivityKind>
    ) -> Bool {
        // 프리미엄 전용 — 무료 사용자는 하루 한 번 한도(`ConsumeLiveActivationUseCase`)를
        // 쓰는데, 자동화를 허용하면 그 한도를 우회하는 뒷문이 된다.
        guard isPremium else { return false }
        // 사용자가 직접 끈 것은 되살리지 않는다 — 끄는 순간 기록에서 빠진다.
        return wanted.contains(kind)
    }

    /// 메모를 게시할 수 있는가 — 되살리기 판단에 **내용 유무**까지 더한다.
    ///
    /// 빈 메모로 시도하면 `StartMemoLiveActivityUseCase`가 throw하고, 자동 경로라 그 실패가
    /// 조용히 삼켜져 사용자에겐 "단축어가 안 먹는다"로만 보인다.
    static func canPublishMemo(_ memo: Memo) -> Bool {
        !memo.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
