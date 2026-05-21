//
//  AppTab.swift
//  cue / Presentation
//

/// 앱의 하단 탭. 탭을 추가하면 case와 메타데이터(`title`·`systemImage`)를 함께 늘린다.
enum AppTab: CaseIterable, Identifiable {
    case reminder
    case settings

    var id: Self { self }

    /// 탭 레이블에 표시할 이름.
    var title: String {
        switch self {
        case .reminder: "미리알림"
        case .settings: "설정"
        }
    }

    /// 탭 아이콘으로 쓸 SF Symbol 이름.
    var systemImage: String {
        switch self {
        case .reminder: "bell"
        case .settings: "gearshape"
        }
    }
}
