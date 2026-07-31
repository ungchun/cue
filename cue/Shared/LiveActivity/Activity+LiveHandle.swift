//
//  Activity+LiveHandle.swift
//  cue / Shared
//

@preconcurrency import ActivityKit

// MARK: - 타깃 멤버십
//
// 인텐트(앱 + 익스텐션 양쪽에 컴파일됨)가 쓰므로 이 파일도 양쪽에 들어간다(pbxproj exception).

extension ActivityState {
    /// 테스트 가능한 생존 상태로 옮긴다 — 판단 규칙은 `LiveActivityHandlePicker`에 있다.
    var handleState: LiveActivityHandleState {
        switch self {
        case .active: return .active
        case .stale: return .stale
        case .ended: return .ended
        case .dismissed: return .dismissed
        @unknown default:
            // 모르는 상태는 죽은 것으로 본다 — 엉뚱한 핸들에 update를 보내느니
            // 아무것도 안 하는 편이 낫다(다음 재게시가 정상 경로로 복구한다).
            return .ended
        }
    }
}

extension Activity {
    /// 갱신을 받을 수 있는 살아있는 인스턴스. 전부 죽었으면 nil.
    ///
    /// `activities.first`를 직접 쓰면 `.ended`/`.dismissed` 인스턴스를 잡을 수 있고,
    /// 거기 보낸 `update()`는 **예외도 없이 무시**된다 — 코드는 성공한 것처럼 끝나고
    /// 화면만 그대로 남는다. 살아있는 LA를 다루는 모든 경로는 이 프로퍼티를 쓴다.
    static var liveActivity: Activity? {
        LiveActivityHandlePicker.liveOne(from: activities) { $0.activityState.handleState }
    }
}
