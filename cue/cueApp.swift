//
//  cueApp.swift
//  cue
//
//  Created by Kim SungHun on 5/20/26.
//

import FirebaseCore
import SwiftData
import SwiftUI

@main
struct cueApp: App {
    /// 앱 의존성을 조립하는 단 하나의 진입점.
    private let composition: CompositionRoot

    init() {
        // Firebase(Analytics·Remote Config)는 다른 어떤 의존성보다 먼저 구성돼야 한다.
        FirebaseApp.configure()
        composition = CompositionRoot()
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: composition.dependencies)
                .environment(\.dependencies, composition.dependencies)
                // 앱 시작 시 시스템에 살아있는 Live Activity 인스턴스를 service가 재포착.
                // 사용자가 강제 종료한 동안에도 시스템이 Activity를 보존하므로 동기화 필수.
                .task {
                    await composition.dependencies.syncLiveActivities()
                }
        }
        .modelContainer(composition.modelContainer)
    }
}
