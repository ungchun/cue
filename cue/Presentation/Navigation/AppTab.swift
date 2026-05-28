//
//  AppTab.swift
//  cue / Presentation
//

/// 앱의 하단 탭. 탭을 추가하면 case와 메타데이터(`title`·`systemImage`)를 함께 늘린다.
/// 탭 선언 순서가 그대로 탭바 좌→우 순서. `allCases`가 그 순서를 보장한다.
enum AppTab: CaseIterable, Identifiable {
    case focus     // 뽀모도로 + 앱 차단 — 화면은 다음 사이클에서.
    case reminder
    case schedule  // 타임라인 + 신규 이벤트 시트(EKEventEditViewController). 시간순 리스트는 다음 사이클에서.
    case settings

    var id: Self { self }

    /// 탭 레이블에 표시할 이름.
    var title: String {
        switch self {
        case .focus: "집중"
        case .reminder: "할일"
        case .schedule: "일정"
        case .settings: "설정"
        }
    }

    /// 탭 아이콘으로 쓸 SF Symbol 이름.
    var systemImage: String {
        switch self {
        case .focus: "timer"
        case .reminder: "list.bullet"
        case .schedule: "calendar"
        case .settings: "gearshape"
        }
    }
}
