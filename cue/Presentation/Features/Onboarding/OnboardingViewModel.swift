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
    @ObservationIgnored private let endScheduleLiveActivityUseCase: EndScheduleLiveActivityUseCase
    @ObservationIgnored private let endReminderLiveActivityUseCase: EndReminderLiveActivityUseCase
    @ObservationIgnored private let fetchAppSettingsUseCase: FetchAppSettingsUseCase
    @ObservationIgnored private let saveAppSettingsUseCase: SaveAppSettingsUseCase

    init(dependencies: Dependencies) {
        fetchMemoUseCase = dependencies.fetchMemo
        saveMemoUseCase = dependencies.saveMemo
        startMemoLiveActivityUseCase = dependencies.startMemoLiveActivity
        startSampleLiveActivitiesUseCase = dependencies.startSampleLiveActivities
        endScheduleLiveActivityUseCase = dependencies.endScheduleLiveActivity
        endReminderLiveActivityUseCase = dependencies.endReminderLiveActivity
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
    /// 성공하면 예시 일정·할일 LA도 함께 띄워 잠금화면 3카드 장면을 만든다(권한·쿼터 불요).
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
            // 주인공(첫 큐)이 떠야 조연도 뜬다 — 메모 실패 시 예시만 남는 잠금화면 방지.
            await startSampleLiveActivitiesUseCase()
        } catch {
            published = false
        }
    }

    /// 예시 일정·할일 LA 종료 — Done/Skip(온보딩 UI 마감) 전용. 가짜 데이터가 잠금화면에
    /// 최대 8시간 남지 않게 하고 메모(진짜 첫 큐)만 남긴다. 온보딩 UI가 떠 있는 동안 실사용
    /// 일정·할일 LA는 존재할 수 없으므로(신규·재개 사용자만 이 화면을 봄) 무조건 종료해도
    /// 안전하다 — 이전 실행이 남긴 예시(재개 후 스킵)도 함께 정리된다.
    /// 조용한 완주 경로(`finish`만 호출)는 부르지 않는다 — 기존 사용자의 실사용 LA 보호.
    func endSampleLiveActivities() async {
        await endScheduleLiveActivityUseCase()
        await endReminderLiveActivityUseCase()
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
