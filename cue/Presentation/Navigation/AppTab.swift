//
//  AppTab.swift
//  cue / Presentation
//

import SwiftUI

/// 앱의 하단 탭. 탭을 추가하면 case와 메타데이터(`title`·`systemImage`)를 함께 늘린다.
/// 탭 선언 순서가 그대로 탭바 좌→우 순서. `allCases`가 그 순서를 보장한다.
/// `String` raw value는 시작 탭 설정(`AppSettings.startTabID`)의 영속 식별자로 쓴다 —
/// case 이름("memo"·"schedule"·"reminder"·"focus"·"settings")이 그대로 저장된다.
enum AppTab: String, CaseIterable, Identifiable {
    case memo      // 메모 — 큰 텍스트 + Live Activity.
    case schedule  // 타임라인 + 신규 이벤트 시트(EKEventEditViewController). 시간순 리스트는 다음 사이클에서.
    case reminder
    case focus     // 뽀모도로 — 단계 종료 알림까지. Live Activity·앱 차단은 다음 사이클.
    case settings  // 설정 — 우측 끝(5번째). role nil이라 다른 탭과 한 캡슐에 같이(분리 안 함).

    var id: Self { self }

    /// 탭 레이블에 표시할 이름.
    var title: LocalizedStringKey {
        switch self {
        case .memo: "Memo"
        case .schedule: "Schedule"
        case .reminder: "Tasks"
        case .focus: "Focus"
        case .settings: "Settings"
        }
    }

    /// 탭 아이콘으로 쓸 SF Symbol 이름.
    var systemImage: String {
        switch self {
        case .memo: "note.text"
        case .schedule: "calendar"
        case .reminder: "list.bullet"
        case .focus: "timer"
        case .settings: "gearshape"
        }
    }


    /// 탭의 시스템 role — 모두 일반(nil). 설정도 `.search`가 아니라 nil이라 다른 탭과 한
    /// 캡슐에 같이 들어간다(분리되지 않고 5개가 나란히).
    var role: TabRole? { nil }
}
