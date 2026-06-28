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

    /// 현재 메모(텍스트 + 색). View는 바인딩으로 읽고, 변경은 `setText`/`setColor`로.
    private(set) var memo: Memo = .default
    /// 메모 입력 글자 크기 — 설정에서 읽어 View가 글꼴에 반영한다. 기본 `.large`(현재 동작).
    private(set) var textSize: MemoTextSize = .large
    /// 라이브 액티비티 활성 상태 — 동그라미 버튼 시각 상태 + 토글 분기.
    private(set) var liveActivityActive = false
    /// 라이브 액티비티 시작 실패 시 사용자에게 알릴 에러 — View가 alert로 표시.
    var errorMessage: String?

    init(dependencies: Dependencies) {
        self.fetchMemoUseCase = dependencies.fetchMemo
        self.saveMemoUseCase = dependencies.saveMemo
        self.startLiveActivityUseCase = dependencies.startMemoLiveActivity
        self.endLiveActivityUseCase = dependencies.endMemoLiveActivity
        self.fetchAppSettings = dependencies.fetchAppSettings
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

    /// 텍스트 변경 — 저장하고, LA가 떠 있으면 반영.
    func setText(_ text: String) async {
        memo.text = text
        await saveMemoUseCase(memo)
        await refreshLiveActivityIfActive()
    }

    /// 색 변경 — 저장하고, LA가 떠 있으면 반영.
    func setColor(_ hex: String) async {
        memo.colorHex = hex
        await saveMemoUseCase(memo)
        await refreshLiveActivityIfActive()
    }

    /// 동그라미 버튼 액션 — 라이브 액티비티 토글.
    /// 활성이면 종료. 아니면 현재 메모로 게시한다(빈 텍스트면 버튼이 비활성이라 평상시 안 옴).
    func toggleLiveActivity() async {
        if liveActivityActive {
            await endLiveActivityUseCase()
            liveActivityActive = false
            return
        }
        guard canStartLiveActivity else { return }
        do {
            try await startLiveActivityUseCase(memo)
            liveActivityActive = true
        } catch {
            errorMessage = "라이브 액티비티를 시작할 수 없습니다."
        }
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
