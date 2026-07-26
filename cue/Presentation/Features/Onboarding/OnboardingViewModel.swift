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
    /// 시작만 하고 중단했으면(마커) 이어서 다시 보여준다 — 온보딩이 저장한 메모가
    /// "기존 설치 흔적"으로 읽혀 조용히 완주 처리되는 오판 방지. 그 외 미완주는
    /// 구버전 저장물이 있는 기존 사용자만 온보딩 없이 조용히 완주 처리한다.
    nonisolated static func launchDecision(
        settings: AppSettings, hasPriorInstall: Bool
    ) -> OnboardingLaunchDecision {
        guard !settings.hasCompletedOnboarding else { return .none }
        if settings.hasStartedOnboarding { return .show }
        return hasPriorInstall ? .markCompletedSilently : .show
    }
    @ObservationIgnored private let fetchMemoUseCase: FetchMemoUseCase
    @ObservationIgnored private let saveMemoUseCase: SaveMemoUseCase
    @ObservationIgnored private let startMemoLiveActivityUseCase: StartMemoLiveActivityUseCase
    @ObservationIgnored private let startSampleLiveActivitiesUseCase: StartSampleLiveActivitiesUseCase
    @ObservationIgnored private let fetchAppSettingsUseCase: FetchAppSettingsUseCase
    @ObservationIgnored private let saveAppSettingsUseCase: SaveAppSettingsUseCase

    /// 무료/프리미엄 분기(재시청 데모 게시)용 — 게시 시점에 읽는다.
    @ObservationIgnored private let premiumStore: PremiumStore

    init(dependencies: Dependencies, premiumStore: PremiumStore) {
        self.premiumStore = premiumStore
        fetchMemoUseCase = dependencies.fetchMemo
        saveMemoUseCase = dependencies.saveMemo
        startMemoLiveActivityUseCase = dependencies.startMemoLiveActivity
        startSampleLiveActivitiesUseCase = dependencies.startSampleLiveActivities
        fetchAppSettingsUseCase = dependencies.fetchAppSettings
        saveAppSettingsUseCase = dependencies.saveAppSettings
    }

    /// 현재 페이지(0~2) — View의 TabView selection과 바인딩.
    var page = 0

    /// 3장 입력 필드의 텍스트.
    var text = ""

    /// 첫 큐가 실제로 게시됐는지 — true면 3장이 "이제 화면을 잠가보세요" 안내로 전환.
    private(set) var published = false

    /// 재시청(설정 "온보딩 다시 보기") 진입 여부 — `reset()`이 켠다. 첫 실행은 false.
    @ObservationIgnored private var isReplay = false

    /// 이번 게시가 placeholder 데모였는지(무료 재시청) — true면 RootView가 메모 LA를
    /// 채택하지 않는다. 채택하면 메모 탭 편집이 쿼터 없이 LA를 갱신하는 우회가 열린다.
    private(set) var publishedDemo = false

    /// 게시 버튼 활성 기준 — 공백만으로는 게시 불가(빈 신호는 의미가 없다).
    var canPublish: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 첫 큐 띄우기 — 입력 텍스트로 메모를 저장하고(기존 색 보존) LA를 게시한다.
    /// 성공하면 예시 일정·할일 LA도 함께 띄워 잠금화면 3카드 장면을 만든다(권한·쿼터 불요).
    /// 실패하면 published로 넘어가지 않는다 — 온보딩에서는 조용히 머무는 게
    /// 에러 알림보다 낫다(다음 화면에서 다시 시도 가능).
    func publish() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // 색은 기존 메모 것을 보존 — 온보딩은 텍스트만 만들고 커스터마이징은 설정의 영역.
        var memo = await fetchMemoUseCase()
        let isDemo = isReplay && !premiumStore.isPremium
        if isDemo {
            // 무료 재시청 — 입력을 실제 메모로 저장하지도 잠금화면에 싣지도 않는다.
            // 저장·게시하면 하루 1회 쿼터를 재시청으로 우회하는 구멍이 된다. 메모 카드는
            // 메모 탭 placeholder 문구로 데모만 보여준다(첫 실행·프리미엄은 기존 그대로).
            memo.text = String(localized: "What to remember?")
        } else {
            memo.text = trimmed
            await saveMemoUseCase(memo)
        }
        do {
            try await startMemoLiveActivityUseCase(memo)
            published = true
            publishedDemo = isDemo
            // 주인공(첫 큐)이 떠야 조연도 뜬다 — 메모 실패 시 예시만 남는 잠금화면 방지.
            // 정리는 Done이 아니라 **다음 앱 실행**(RootView)에서 — Done을 바로 눌러도
            // 이번 세션 동안 3카드 장면이 유지되게 하기 위함.
            await startSampleLiveActivitiesUseCase()
        } catch {
            published = false
        }
    }

    /// 재시청(설정 "온보딩 다시 보기") 진입 직전 호출 — 진행 상태를 처음으로 되돌리고
    /// 재시청 표식을 켠다(무료 사용자의 데모 게시 분기 근거). 첫 실행 경로는 부르지 않는다.
    /// 지난 시청의 입력·"게시 완료" 화면이 그대로 다시 열리지 않게.
    func reset() {
        page = 0
        text = ""
        published = false
        publishedDemo = false
        isReplay = true
    }

    /// 표시 직전 시작 마커 저장 — 중단 후 재실행 시 이어서 보여주기 위한 근거.
    func markStarted() async {
        var settings = await fetchAppSettingsUseCase()
        guard !settings.hasStartedOnboarding else { return }
        settings.hasStartedOnboarding = true
        await saveAppSettingsUseCase(settings)
    }

    /// 완료·스킵 공통 마감 — 완주 플래그만 저장하고 다른 설정은 보존한다.
    func finish() async {
        var settings = await fetchAppSettingsUseCase()
        guard !settings.hasCompletedOnboarding else { return }
        settings.hasCompletedOnboarding = true
        await saveAppSettingsUseCase(settings)
    }
}
