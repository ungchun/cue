//
//  OnboardingViewModel.swift
//  cue / Presentation
//

import Foundation
import Observation

/// 첫 실행 온보딩 상태 — 3장(컨셉 → 가치 → 첫 큐 띄우기)의 진행과 첫 큐 게시를 다룬다.
///
/// 첫 큐 게시는 **쿼터를 소비하지 않는다** — 온보딩이 무료 하루 한도를 갉아먹으면
/// 첫날 경험이 나빠지므로, `MemoViewModel.toggleLiveActivity`와 달리
/// `consumeLiveActivation` 없이 use case를 직접 호출한다.
/// 앱 시작 시 온보딩 처리 — 표시 / 조용한 완주 처리(기존 사용자 마이그레이션) / 없음.
enum OnboardingLaunchDecision: Equatable {
    case show
    case markCompletedSilently
    case none
}

@MainActor
@Observable
final class OnboardingViewModel {

    /// 앱 시작 시 온보딩 표시 판정 — 한 번이라도 완주(스킵 포함)했으면 다시 안 뜬다.
    /// 미완주여도 구버전 저장물이 있는 **기존 사용자**는 업데이트 직후 온보딩 없이
    /// 조용히 완주 처리한다(잘 쓰던 사람에게 소개 화면을 끼얹지 않는다).
    nonisolated static func launchDecision(
        settings: AppSettings, hasPriorInstall: Bool
    ) -> OnboardingLaunchDecision {
        guard !settings.hasCompletedOnboarding else { return .none }
        return hasPriorInstall ? .markCompletedSilently : .show
    }
    @ObservationIgnored private let fetchMemoUseCase: FetchMemoUseCase
    @ObservationIgnored private let saveMemoUseCase: SaveMemoUseCase
    @ObservationIgnored private let startMemoLiveActivityUseCase: StartMemoLiveActivityUseCase
    @ObservationIgnored private let fetchAppSettingsUseCase: FetchAppSettingsUseCase
    @ObservationIgnored private let saveAppSettingsUseCase: SaveAppSettingsUseCase

    init(dependencies: Dependencies) {
        fetchMemoUseCase = dependencies.fetchMemo
        saveMemoUseCase = dependencies.saveMemo
        startMemoLiveActivityUseCase = dependencies.startMemoLiveActivity
        fetchAppSettingsUseCase = dependencies.fetchAppSettings
        saveAppSettingsUseCase = dependencies.saveAppSettings
    }

    /// 현재 페이지(0~2) — View의 TabView selection과 바인딩.
    var page = 0

    /// 3장 입력 필드의 텍스트.
    var text = ""

    /// 첫 큐가 실제로 게시됐는지 — true면 3장이 "이제 화면을 잠가보세요" 안내로 전환.
    private(set) var published = false

    /// 게시 버튼 활성 기준 — 공백만으로는 게시 불가(빈 신호는 의미가 없다).
    var canPublish: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 첫 큐 띄우기 — 입력 텍스트로 메모를 저장하고(기존 색 보존) LA를 게시한다.
    /// 실패하면 published로 넘어가지 않는다 — 온보딩에서는 조용히 머무는 게
    /// 에러 알림보다 낫다(다음 화면에서 다시 시도 가능).
    func publish() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // 색은 기존 메모 것을 보존 — 온보딩은 텍스트만 만들고 커스터마이징은 설정의 영역.
        var memo = await fetchMemoUseCase()
        memo.text = trimmed
        await saveMemoUseCase(memo)
        do {
            try await startMemoLiveActivityUseCase(memo)
            published = true
        } catch {
            published = false
        }
    }

    /// 완료·스킵 공통 마감 — 완주 플래그만 저장하고 다른 설정은 보존한다.
    func finish() async {
        var settings = await fetchAppSettingsUseCase()
        guard !settings.hasCompletedOnboarding else { return }
        settings.hasCompletedOnboarding = true
        await saveAppSettingsUseCase(settings)
    }
}
