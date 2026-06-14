//
//  FocusAlarmMetadata.swift
//  cue / Shared
//

import AlarmKit
import Foundation

// MARK: - 타깃 멤버십
//
// 메인 앱(`AlarmManager.schedule`)과 위젯 익스텐션(`AlarmAttributes<FocusAlarmMetadata>` 렌더) 양쪽이
// 참조한다 — pbxproj exception으로 `cueLiveActivityExtension`에도 포함돼야 한다.

/// AlarmKit Live Activity가 싣는 단계 메타데이터.
///
/// AlarmKit이 카운트다운·버튼 UI를 시스템에서 구동하므로, 위젯이 표시할 부가 정보(단계·사이클·
/// 세션 타이틀·색)만 담는다. `AlarmMetadata`는 Codable·Hashable·Sendable을 요구하며 멤버가 모두
/// 충족해 자동 conformance 된다.
struct FocusAlarmMetadata: AlarmMetadata {
    enum Phase: String, Codable, Sendable, Hashable {
        case focus
        case rest
    }

    /// 이 알람이 나타내는 단계.
    let phase: Phase
    /// 현재 사이클 번호(1-base).
    let cycle: Int
    /// 총 사이클 수 — "1 / N" 표시·종료 판정용.
    let totalCycles: Int
    /// 세션 표시 타이틀 — 위젯 상단(앱 화면 titleHeader와 동일 톤). 미선택 시 "Cue".
    let sessionTitle: String
    /// 세션 색 hex — 위젯 ring·아이콘 tint. nil이면 앱 프라이머리(indigo) 폴백.
    let colorHex: String?
}
