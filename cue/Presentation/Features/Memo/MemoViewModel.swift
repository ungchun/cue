//
//  MemoViewModel.swift
//  cue / Presentation
//

import Foundation
import Observation

/// 메모 탭의 상태 + 동작.
///
/// 단일 메모(텍스트 + 색)를 입력·저장하고, 동그라미 버튼으로 라이브 액티비티를 토글한다.
/// 텍스트가 비어 있으면 라이브 액티비티를 시작할 수 없다 — View는 `canStartLiveActivity`로
/// 버튼을 비활성화하고, use case가 마지막 방어선으로 빈 텍스트를 거른다.
///
/// 저장은 변경 즉시(텍스트·색) — 메모 하나라 UserDefaults 통째 write로 가볍다. 라이브
/// 액티비티가 떠 있으면 변경을 곧바로 반영(update)하고, 텍스트가 비면 종료한다.
@MainActor
@Observable
final class MemoViewModel {
    private let fetchMemoUseCase: FetchMemoUseCase
    private let saveMemoUseCase: SaveMemoUseCase
    private let startLiveActivityUseCase: StartMemoLiveActivityUseCase
    private let endLiveActivityUseCase: EndMemoLiveActivityUseCase
    private let fetchAppSettings: FetchAppSettingsUseCase
    private let consumeLiveActivation: ConsumeLiveActivationUseCase
    private let analytics: any AnalyticsService
    /// 프리미엄 여부의 반응형 소스 — 라이브 한도 소비 시 호출 시점에 읽는다(구매 즉시 반영).
    private let premiumStore: PremiumStore

    /// 현재 메모(텍스트 + 색). View는 바인딩으로 읽고, 변경은 `setText`/`setColor`로.
    private(set) var memo: Memo = .default
    /// 메모 입력 글자 크기 — 설정에서 읽어 View가 글꼴에 반영한다. 기본 `.medium`.
    private(set) var textSize: MemoTextSize = .medium
    /// 라이브 액티비티 활성 상태 — 동그라미 버튼 시각 상태 + 토글 분기.
    private(set) var liveActivityActive = false
    /// 라이브 액티비티 시작 실패 시 사용자에게 알릴 에러 — View가 alert로 표시.
    var errorMessage: String?

    init(dependencies: Dependencies, premiumStore: PremiumStore = PremiumStore(service: DisabledPurchaseService())) {
        self.premiumStore = premiumStore
        self.fetchMemoUseCase = dependencies.fetchMemo
        self.saveMemoUseCase = dependencies.saveMemo
        self.startLiveActivityUseCase = dependencies.startMemoLiveActivity
        self.endLiveActivityUseCase = dependencies.endMemoLiveActivity
        self.fetchAppSettings = dependencies.fetchAppSettings
        self.consumeLiveActivation = dependencies.consumeLiveActivation
        self.analytics = dependencies.analytics
    }

    /// 빈 텍스트(공백만 포함)면 라이브 액티비티를 시작할 수 없다 — 버튼 비활성 기준.
    var canStartLiveActivity: Bool {
        !memo.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 화면이 나타날 때 — 저장된 메모 + 글자 크기 설정을 불러온다.
    func onAppear() async {
        memo = await fetchMemoUseCase()
        textSize = await fetchAppSettings().memoTextSize
    }

    /// 입력 최대 글자 수 — LA에 실리는 상한(`StartMemoLiveActivityUseCase.maxTextLength`)과
    /// 동일하게 묶어 "적은 만큼 잠금화면에 다 보인다"를 보장한다(조용한 잘림 방지).
    static var maxTextLength: Int { StartMemoLiveActivityUseCase.maxTextLength }

    /// 텍스트 변경 — 상한(120자)으로 잘라 저장하고, LA가 떠 있으면 반영.
    /// 분석은 키 입력마다가 아니라 빈↔내용 전환에 1회만 — "빈 → 내용"은 새 메모 작성
    /// 신호(`memoSaved`), "내용 → 빈"은 지우기 신호(`memoCleared`). 빈 → 빈은 무음.
    func setText(_ text: String) async {
        let capped = String(text.prefix(Self.maxTextLength))
        let wasEmpty = memo.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isEmpty = capped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        memo.text = capped
        await saveMemoUseCase(memo)
        if wasEmpty, !isEmpty {
            analytics.log(.memoSaved)
        } else if !wasEmpty, isEmpty {
            analytics.log(.memoCleared)
        }
        await refreshLiveActivityIfActive()
    }

    /// 색 변경 — 저장하고, LA가 떠 있으면 반영.
    func setColor(_ hex: String) async {
        memo.colorHex = hex
        await saveMemoUseCase(memo)
        await refreshLiveActivityIfActive()
    }

    /// 켜기 버튼 액션 — 꺼져 있으면 켜고, **떠 있으면 끄고 다시 켠다(새로고침)**. 더는 단순
    /// 종료하지 않는다. 빈 텍스트면 버튼이 비활성이라 평상시 이 경로로 오지 않는다(마지막 방어선).
    /// 무료 하루 한도(켜기·새로고침 공통)를 먼저 소비한다 — `.denied`면 기존 LA를 건드리지
    /// 않고 그대로 반환(뷰가 Premium 토스트), `.allowed`면 잔여 횟수 반환(뷰가 "1/2" 토스트).
    @discardableResult
    func toggleLiveActivity() async -> LiveActivationVerdict? {
        guard canStartLiveActivity else { return nil }
        let verdict = await consumeLiveActivation(isPremium: premiumStore.isPremium)
        // .allowed(무료 한도 내)·.unlimited(Premium) 모두 켠다 — .denied(한도 초과)만 막는다.
        if case .denied = verdict {
            analytics.log(.liveDenied(kind: "memo"))
            return verdict
        }
        if liveActivityActive {
            await endLiveActivityUseCase()
            liveActivityActive = false
        }
        do {
            try await startLiveActivityUseCase(memo)
            liveActivityActive = true
            analytics.log(.liveToggled(kind: "memo", on: true))
        } catch {
            errorMessage = String(localized: "Couldn't start Live Activity.")
            return nil
        }
        return verdict
    }

    /// 항상 표시 자동 게시 — 앱 시작·포그라운드 복귀·설정 켬에서 호출.
    /// 사용자 탭이 아니므로 하루 쿼터를 소비하지 않는다(항상 표시는 Premium 전용 기능).
    /// 이 실행에서 이미 켜져 있으면 건너뛴다(복귀마다 재시작 방지). 빈 메모도 건너뛴다.
    /// `force`면 이미 활성이어도 다시 게시한다 — 설정에서 표시 순서를 바꾼 직후,
    /// 새 순서로 다시 쌓기 위해 전 종류를 재게시하는 경로(할일 VM의 force와 동일).
    func startAlwaysOnLiveActivity(force: Bool = false) async {
        // 항상 표시는 Premium 전용 — 게시 시점에 재확인한다. 설정 켜기 게이트만으로는
        // 구독 만료·과거 저장값(liveAlwaysOn=true 잔존)이 무료로 무제한 게시되는 걸 못 막는다.
        guard premiumStore.isPremium else { return }
        guard force || !liveActivityActive else { return }
        // force 재게시는 **끝내고 새로 시작**한다 — 살아 있는 LA는 서비스가 제자리
        // update로 처리해(깜빡임 방지) 잠금화면 쌓임 순서가 안 바뀐다. 순서는 게시
        // 시점이 정하므로, 순서 변경 반영은 재요청만이 유일한 길이다.
        if force, liveActivityActive {
            await endLiveActivityUseCase()
            liveActivityActive = false
        }
        memo = await fetchMemoUseCase()
        guard canStartLiveActivity else { return }
        do {
            try await startLiveActivityUseCase(memo)
            liveActivityActive = true
        } catch {
            // 자동 경로 — 사용자 흐름을 방해하지 않도록 조용히 무시.
        }
    }

    /// 외부(온보딩)에서 **이미 게시된** 메모 LA를 이 VM이 켠 것으로 넘겨받는다 —
    /// 버튼 상태·자동 갱신을 살리고, 사용자가 다시 켜며 쿼터를 낭비하지 않게.
    /// 재게시하지 않는다(이미 떠 있는 활동을 그대로 채택).
    func adoptExternalLiveActivity() {
        liveActivityActive = true
    }

    /// LA가 떠 있을 때 변경을 반영 — 텍스트가 비면(use case가 throw) 종료한다.
    private func refreshLiveActivityIfActive() async {
        guard liveActivityActive else { return }
        do {
            try await startLiveActivityUseCase(memo)
        } catch {
            await endLiveActivityUseCase()
            liveActivityActive = false
        }
    }
}
