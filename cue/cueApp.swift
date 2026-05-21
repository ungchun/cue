//
//  cueApp.swift
//  cue
//
//  Created by Kim SungHun on 5/20/26.
//

import SwiftData
import SwiftUI

@main
struct cueApp: App {
    /// 앱 의존성을 조립하는 단 하나의 진입점.
    private let composition = CompositionRoot()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.dependencies, composition.dependencies)
        }
        .modelContainer(composition.modelContainer)
    }
}
