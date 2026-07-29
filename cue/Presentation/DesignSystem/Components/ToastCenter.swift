//
//  ToastCenter.swift
//  cue / Presentation
//

import SwiftUI

/// 앱 전반에서 쓰는 토스트의 표시 상태를 들고 있는 코디네이터.
///
/// `RootView`가 소유하고 환경(`\.toastCenter`)으로 주입한다 — 어느 화면에서든
/// `showLive()`로 상단 토스트를 띄울 수 있다. 표시 시각(슬라이드·오버레이)은
/// `liveToastOverlay` 모디파이어가, 자동 해제 타이머는 이 타입이 맡는다.
@MainActor
@Observable
final class ToastCenter {
    /// 현재 토스트가 떠 있는지 — 오버레이가 이 값으로 슬라이드 인/아웃한다.
    private(set) var isPresented = false
    /// 캡슐 안 라벨 — "라이브"(새로 켬) / "새로고침"(재시작) / "Premium"(유료 전용 안내).
    private(set) var message = String(localized: "Live")
    /// 프리미엄 안내 토스트인지 — 오버레이가 탭 제스처(페이월 열기)를 붙이는 기준.
    private(set) var isPremiumToast = false
    /// 프리미엄 토스트 탭 시 실행 — RootView가 페이월 시트 열기를 주입한다.
    /// 게이트 호출처(각 화면)는 페이월 표시 지점을 몰라도 되게 여기로 결합을 모은다.
    var premiumTapHandler: (() -> Void)?

    /// 토스트를 그릴 수 있는 오버레이들 — 등록 **순서**가 화면 층위다.
    ///
    /// 시트는 SwiftUI가 별도 프레젠테이션 레이어에 올려서, `RootView`에 붙은 오버레이 하나로는
    /// 시트 위에 토스트를 못 띄운다. 그래서 시트에도 오버레이를 붙이는데, 그러면 이번엔 둘 다
    /// 그려서 `.large` 시트 위쪽 틈으로 루트 토스트가 삐져나와 **두 개로 보인다**.
    /// 가장 나중에 등록된 하나만 그리게 해 그걸 막는다 — 시트는 루트보다 늦게 나타난다.
    private var hostStack: [UUID] = []

    /// 지금 떠 있는 토스트의 **주인** — 띄우는 순간의 맨 위 오버레이로 고정된다.
    ///
    /// 층위를 매번 다시 계산하지 않고 표시 시점에 못 박는 이유는, 토스트가 뜬 채로 시트를
    /// 내리는 경우 때문이다. 그때 층위를 다시 계산하면 주인이 루트로 넘어가면서 사용자가
    /// 방금 떠난 맥락의 안내가 **뒤 화면에 불쑥 나타난다**. 주인이 사라지면 토스트도 같이 끝난다.
    private var ownerHost: UUID?

    /// 자동 해제 타이머 — 새 토스트가 뜨면 이전 타이머를 취소하고 다시 건다(연속 호출 안전).
    private var dismissTask: Task<Void, Never>?

    /// 화면 상단에 머무는 시간 — 이 시간이 지나면 스스로 올라간다.
    private static let visibleDuration: Duration = .seconds(2.5)

    /// 비격리 init — 환경 기본값(`@Entry`)이 비격리 컨텍스트에서 만들 수 있게 한다.
    /// 저장 프로퍼티 기본값만 세팅하므로 메인 액터 격리 상태를 건드리지 않는다.
    nonisolated init() {}

    /// 토스트를 띄운다 — 메모·일정·할일의 "켜기"가 라이브 액티비티를 켜거나(새로 시작)
    /// 다시 눌러 재시작했을 때 호출. `message`로 "라이브"/"새로고침"을 구분해 넘긴다.
    func show(_ message: String) {
        self.message = message
        isPremiumToast = false
        ownerHost = hostStack.last
        isPresented = true
        scheduleAutoDismiss()
    }

    /// 프리미엄 전용 안내 토스트 — 탭하면 페이월로 이어진다(`premiumTapHandler`).
    /// 게이트에 걸린 순간이 구매 의향이 가장 높은 순간이라, 토스트를 결제 진입점으로 쓴다.
    func showPremium() {
        // 브랜드어라 로컬라이즈하지 않는다 — 기존 게이트 호출처의 리터럴 표기와 동일.
        message = "Premium"
        isPremiumToast = true
        ownerHost = hostStack.last
        isPresented = true
        scheduleAutoDismiss()
    }

    /// 토스트 탭 — 프리미엄 토스트면 닫고 페이월 핸들러를 부른다. 일반 토스트는 no-op.
    func handleTap() {
        guard isPresented, isPremiumToast else { return }
        dismiss()
        premiumTapHandler?()
    }

    /// 오버레이가 화면에 나타났다 — 층위 맨 위로 올라간다.
    func registerHost(_ id: UUID) {
        hostStack.removeAll { $0 == id }
        hostStack.append(id)
    }

    /// 오버레이가 사라졌다 — 순서가 아니라 **id로** 지운다. SwiftUI는 새 시트의 `onAppear`가
    /// 이전 시트의 `onDisappear`보다 먼저 오기도 해서, 마지막 원소를 무작정 빼면 엉뚱한
    /// 오버레이가 떨어져 나간다.
    /// 주인이 사라졌다면 토스트도 함께 끝낸다 — 뒤 화면으로 넘겨주지 않는다.
    func unregisterHost(_ id: UUID) {
        hostStack.removeAll { $0 == id }
        guard ownerHost == id else { return }
        dismiss()
    }

    /// 이 오버레이가 지금 토스트를 그려야 하는가 — 띄운 곳 하나만 그린다.
    func shouldRender(host id: UUID) -> Bool {
        ownerHost == id
    }

    /// 사용자가 위로 밀거나(스와이프) 즉시 닫아야 할 때 호출 — 자동 타이머도 함께 끈다.
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        ownerHost = nil
        isPresented = false
    }

    private func scheduleAutoDismiss() {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: Self.visibleDuration)
            guard !Task.isCancelled else { return }
            // 주인도 함께 비운다 — 남겨두면 그 오버레이가 나중에 사라질 때
            // `unregisterHost`가 이미 끝난 토스트를 또 닫으려 한다.
            self?.ownerHost = nil
            self?.isPresented = false
        }
    }
}

extension EnvironmentValues {
    /// 앱 전반 토스트 코디네이터. 기본값은 새 인스턴스 — `RootView`가 소유한 것을 주입해 쓴다.
    @Entry var toastCenter = ToastCenter()
}
