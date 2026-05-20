//
//  RootView.swift
//  cue / App
//

import SwiftUI

/// 앱의 첫 화면. 네비게이션 컨테이너를 소유하고 첫 Feature를 띄운다.
struct RootView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var router = AppRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            ItemListView(dependencies: dependencies)
                .navigationDestination(for: AppRoute.self) { route in
                    route.destination(dependencies: dependencies)
                }
        }
        .environment(router)
    }
}

#Preview {
    RootView()
}
