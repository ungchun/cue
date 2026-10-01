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
    // 표시 문구는 설정 화면과 같은 키를 쓴다 — 번역이 이미 있고, 앱과 단축어의 이름이 같아야 한다.
    static let caseDisplayRepresentations: [RefreshLiveKind: DisplayRepresentation] = [
        .memo: "Memo",
        .reminder: "Tasks",
        .schedule: "Schedule",
    ]

    var liveKind: LiveActivityKind {
        switch self {
        case .memo: .memo
        case .reminder: .reminder
        case .schedule: .schedule
        }
    }
}
