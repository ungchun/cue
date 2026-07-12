//
//  AppRoute.swift
//  cue / Presentation
//

import SwiftUI

/// 앱 내 화면 이동 경로. 새 화면을 추가하면 case와 `destination`을 함께 추가한다.
enum AppRoute: Hashable {
    case itemDetail(itemID: UUID)
}

extension AppRoute {
    /// 경로에 대응하는 목적지 화면을 만든다.
    @MainActor
    @ViewBuilder
    func destination(dependencies: Dependencies) -> some View {
        switch self {
        case .itemDetail(let itemID):
            // TODO: 실제 상세 Feature 화면으로 교체.
            Text("Item Detail\n\(itemID.uuidString)")
                .multilineTextAlignment(.center)
                .navigationTitle("Detail")
        }
    }
}
