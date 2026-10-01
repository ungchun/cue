//
//  RefreshLiveKind.swift
//  cue / Shared
//

import AppIntents

/// 단축어 「라이브 새로고침」에서 고르는 라이브 종류 — 하나, 또는 「라이브」(켜져 있는 전부).
///
/// `LiveActivityKind`를 그대로 쓰지 않는 이유 — Domain은 `AppIntents`를 import하지 않는다.
/// 집중은 빠진다 — AlarmKit으로 이관돼 8시간 한도의 대상이 아니다.
///
/// **raw 값은 사용자 자동화에 저장된다** — 바꾸거나 지우면 이미 만든 자동화가 깨진다.
enum RefreshLiveKind: String, AppEnum {
    // 선언 순서가 단축어 선택 목록의 순서다 — 「라이브」(전부)를 맨 위에 둔다.
    /// 켜져 있는 종류 전부. 백그라운드에선 실행 한 번에 하나만 새로 켜지는 것으로 보여
    /// (`RefreshLiveIntent.kind` 주석 참고) 셋 다 갱신된다는 보장은 없다.
    case all
    case memo
    case reminder
    case schedule

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Live"
    // 표시 문구는 설정 화면과 같은 키를 쓴다 — 번역이 이미 있고, 앱과 단축어의 이름이 같아야 한다.
    static let caseDisplayRepresentations: [RefreshLiveKind: DisplayRepresentation] = [
        .all: "Live",
        .memo: "Memo",
        .reminder: "Tasks",
        .schedule: "Schedule",
    ]

    /// 러너에 넘길 종류 — 전부면 nil.
    var liveKind: LiveActivityKind? {
        switch self {
        case .memo: .memo
        case .reminder: .reminder
        case .schedule: .schedule
        case .all: nil
        }
    }
}
