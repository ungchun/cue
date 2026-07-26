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
        isPresented = true
        scheduleAutoDismiss()
    }

    /// 프리미엄 전용 안내 토스트 — 탭하면 페이월로 이어진다(`premiumTapHandler`).
    /// 게이트에 걸린 순간이 구매 의향이 가장 높은 순간이라, 토스트를 결제 진입점으로 쓴다.
    func showPremium() {
        // 브랜드어라 로컬라이즈하지 않는다 — 기존 게이트 호출처의 리터럴 표기와 동일.
        message = "Premium"
        isPremiumToast = true
        isPresented = true
        scheduleAutoDismiss()
    }

    /// 토스트 탭 — 프리미엄 토스트면 닫고 페이월 핸들러를 부른다. 일반 토스트는 no-op.
    func handleTap() {
        guard isPresented, isPremiumToast else { return }
        dismiss()
        premiumTapHandler?()
    }

    /// 사용자가 위로 밀거나(스와이프) 즉시 닫아야 할 때 호출 — 자동 타이머도 함께 끈다.
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        isPresented = false
    }

    private func scheduleAutoDismiss() {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: Self.visibleDuration)
            guard !Task.isCancelled else { return }
            self?.isPresented = false
        }
    }
}

extension EnvironmentValues {
    /// 앱 전반 토스트 코디네이터. 기본값은 새 인스턴스 — `RootView`가 소유한 것을 주입해 쓴다.
    @Entry var toastCenter = ToastCenter()
}
