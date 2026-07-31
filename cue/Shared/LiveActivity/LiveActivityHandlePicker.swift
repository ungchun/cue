//
//  LiveActivityHandlePicker.swift
//  cue / Shared
//

import Foundation

// MARK: - 타깃 멤버십
//
// 인텐트(앱 + 익스텐션 양쪽에 컴파일됨)가 참조하므로 이 파일도 양쪽에 들어간다(pbxproj exception).
// 시스템 프레임워크조차 import하지 않는 순수 규칙이라 어느 타깃에서도 안전하다.

/// LA 인스턴스의 생존 상태 — ActivityKit `ActivityState`를 테스트 가능한 형태로 옮긴 것.
///
/// `ActivityState`는 유닛 테스트에서 인스턴스를 만들 수 없어(실제 LA가 있어야 한다) 규칙을
/// 검증할 수 없다. 판단에 필요한 건 "쓸 수 있는 핸들인가" 하나뿐이라 그것만 떼어낸다.
enum LiveActivityHandleState: Sendable, Equatable {
    /// 화면에 떠 있고 갱신이 반영된다.
    case active
    /// 화면에 떠 있지만 내용이 오래됐다고 시스템이 표시한 상태 — **갱신하면 되살아난다**.
    case stale
    /// 시스템이 종료(8시간 만료 등). 갱신해도 무시된다.
    case ended
    /// 사용자가 잠금화면에서 치웠다. 갱신해도 무시된다.
    case dismissed

    /// 지금 갱신을 보내면 화면에 반영되는가.
    ///
    /// `.stale`을 살아있는 것으로 보는 게 핵심이다 — 오래된 카드야말로 갱신이 필요한
    /// 대상인데 이걸 죽은 것으로 취급하면 영영 고칠 수 없다.
    var acceptsUpdates: Bool {
        switch self {
        case .active, .stale: return true
        case .ended, .dismissed: return false
        }
    }
}

/// 살아있는 LA 핸들을 고르는 규칙.
///
/// **왜 필요한가** — `Activity.activities`는 `.active`만 담지 않는다. 시스템이 종료한
/// (`.ended`) · 사용자가 치운(`.dismissed`) 인스턴스도 한동안 함께 남아 있고, `.first`는
/// 정렬을 보장하지 않는다. 죽은 인스턴스에 `update()`를 하면 **예외도 반환값도 없이
/// 무시**되어, 코드는 성공한 것처럼 끝나고 화면만 그대로 남는다.
///
/// 실제 증상: 갓 켠 LA에서는 할일 체크가 잘 먹는데(살아있는 인스턴스 하나뿐이라 `.first`가
/// 반드시 맞는 것을 잡는다), 시간이 지나 종료된 인스턴스가 쌓이면 체크해도 카드가 그대로였다.
/// EventKit 저장은 이 목록과 무관하게 먼저 끝나므로 "순정 앱엔 완료, LA엔 그대로"가 된다.
enum LiveActivityHandlePicker {

    /// 갱신을 받을 수 있는 첫 핸들. 전부 죽었으면 nil — 그때는 아무것도 하지 않는 게 맞다.
    ///
    /// - Parameter state: 각 핸들에서 생존 상태를 읽는 키패스. 실제 `Activity`는
    ///   `activityState`를 주고, 테스트는 대역의 프로퍼티를 준다.
    static func liveOne<Handle>(
        from handles: [Handle],
        state: (Handle) -> LiveActivityHandleState
    ) -> Handle? {
        handles.first { state($0).acceptsUpdates }
    }
}
