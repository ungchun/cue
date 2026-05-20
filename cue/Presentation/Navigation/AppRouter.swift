//
//  AppRouter.swift
//  cue / Presentation
//

import SwiftUI

/// 네비게이션 상태 보유자. View들이 `@Environment`로 접근해 경로를 조작한다.
@MainActor
@Observable
final class AppRouter {
    var path = NavigationPath()

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
