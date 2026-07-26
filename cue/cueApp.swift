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
            RootView(dependencies: composition.dependencies, premiumStore: composition.premiumStore)
                .environment(\.dependencies, composition.dependencies)
                .environment(\.premiumStore, composition.premiumStore)
                // 앱 시작 시 시스템에 살아있는 Live Activity 인스턴스를 service가 재포착.
                // 사용자가 강제 종료한 동안에도 시스템이 Activity를 보존하므로 동기화 필수.
                .task {
                    await composition.dependencies.syncLiveActivities()
                }
                // 상품 로드 + 현재 엔타이틀먼트 반영 + 구매 변경 스트림 구독.
                // 이어서 강등(비프리미엄) 사용자의 프리미엄 전용 설정 잔존값을 정리한다 —
                // 정리됐으면 떠 있는 LA를 재게시해 캘린더 등 프리미엄 표시를 즉시 걷는다.
                .task {
                    // 첫 refresh가 confirmedIsPremium을 확정하면 RootView의
                    // onChange(confirmedIsPremium)가 reconcile(강등 접어두기/재구독 복구)을
                    // 단일 지점에서 실행한다 — 여기서 병행 호출하면 같은 전이에 이중 실행.
                    await composition.premiumStore.start()
                }
        }
        .modelContainer(composition.modelContainer)
    }
}
