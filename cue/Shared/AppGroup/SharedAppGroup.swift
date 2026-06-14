//
//  SharedAppGroup.swift
//  cue / Shared
//

import Foundation

/// 메인 앱과 widget extension(App Intent) 사이의 공유 통로.
///
/// 두 target 모두 Xcode의 Signing & Capabilities에서 동일 App Group ID로 entitlement이
/// 추가돼 있어야 한다 — 추가되지 않으면 `UserDefaults(suiteName:)`이 nil을 반환하고
/// `.standard`로 폴백(이때 process 간 공유는 깨진다 — 디버그 시 entitlement부터 확인).
///
/// 현재는 집중 세션 설정 스냅샷(`FocusAlarmPlan`)이 사용한다 — 메인 앱이 저장하고 위젯 익스텐션의
/// AlarmKit 체이닝 인텐트가 읽는다. 향후 다른 공유 상태도 같은 suite를 통한다.
enum SharedAppGroup {
    /// Group ID. Xcode entitlement(`com.apple.security.application-groups`)에 같은 값을
    /// 두 target 모두에 등록해야 process 간 공유가 작동한다.
    static let identifier = "group.azhy.cue"

    /// 두 process가 공유하는 UserDefaults. entitlement 누락 시 `.standard`로 폴백 —
    /// 단일 process 내 동작은 유지되지만 공유는 끊긴다.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
