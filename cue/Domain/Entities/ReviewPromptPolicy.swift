//
//  ReviewPromptPolicy.swift
//  cue / Domain
//

import Foundation

/// 리뷰 요청을 언제 띄울지 정하는 규칙.
///
/// 기준은 **라이브를 실제로 띄운 서로 다른 날의 수**다 — 버튼을 몇 번 눌렀는지가 아니라.
/// 누른 횟수는 "띄워두려는 의도"일 뿐이고, cue의 가치는 잠금화면에서 나중에 실현된다.
/// 여러 날에 걸쳐 돌아왔다는 것이 "쓸모 있었다"의 유일한 관측 가능한 증거다.
/// 하루 안에 몇 번을 띄우든 1일로 센다 — 무료(하루 1회)와 프리미엄(무제한)이
/// 같은 속도로 문턱에 닿게 하려는 것. 횟수로 세면 프리미엄은 10분 만에 채운다.
enum ReviewPromptPolicy {
    /// 요청할 사용일 수. 도달한 값은 `ReviewPromptState.promptedThresholds`에 기록돼 다시 뜨지 않는다.
    /// 지금은 하나뿐이라 결과적으로 평생 1회 — 나중에 2차를 열려면 값만 추가하면 된다
    /// (Apple이 1년 3회로 제한하므로 늘려도 사용자가 시달리지 않는다).
    static let thresholds: Set<Int> = [4]

    /// 지금 요청해야 할 문턱 — 없으면 nil.
    ///
    /// `>=` 비교인 이유: `== 4`로 두면 4일째에 요청을 놓쳤을 때(쿼터 초과로 게시 실패,
    /// 그 순간 앱 종료 등) 다음 날 5가 되어 영영 조건에 걸리지 않는다. 이미 요청한 문턱은
    /// `prompted`가 막으므로 `>=`여도 중복 발화하지 않는다.
    /// 여러 문턱을 동시에 넘겼다면 가장 큰 것 하나만 — 한 번에 두 번 묻지 않는다.
    static func pendingThreshold(dayCount: Int, prompted: Set<Int>) -> Int? {
        thresholds
            .filter { dayCount >= $0 && !prompted.contains($0) }
            .max()
    }
}
