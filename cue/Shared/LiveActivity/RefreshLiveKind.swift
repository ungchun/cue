//
//  RefreshLiveKind.swift
//  cue / Shared
//

import AppIntents

/// 단축어 「라이브 새로고침」에서 고르는 라이브 종류.
///
/// `LiveActivityKind`를 그대로 쓰지 않는 이유 — Domain은 `AppIntents`를 import하지 않는다.
/// 집중은 빠진다 — AlarmKit으로 이관돼 8시간 한도의 대상이 아니다.
///
/// **raw 값은 사용자 자동화에 저장된다** — 바꾸거나 지우면 이미 만든 자동화가 깨진다.
enum RefreshLiveKind: String, AppEnum {
    case memo
    case reminder
    case schedule

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Live"
    // 「라이브」를 붙여 단축어 목록에서 무엇을 새로고침하는지 바로 읽히게 한다(메모 라이브 등).
    static let caseDisplayRepresentations: [RefreshLiveKind: DisplayRepresentation] = [
        .memo: "Memo Live",
        .reminder: "Tasks Live",
        .schedule: "Schedule Live",
    ]

    var liveKind: LiveActivityKind {
        switch self {
        case .memo: .memo
        case .reminder: .reminder
        case .schedule: .schedule
        }
    }
}
