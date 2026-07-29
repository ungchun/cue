//
//  LiveToastOverlay.swift
//  cue / Presentation
//

import SwiftUI

/// 화면 상단에서 내려오는 라이브 토스트 오버레이. `ToastCenter`가 표시를 제어하고,
/// 이 모디파이어는 상단 슬라이드 인/아웃 + 위로 스와이프해 닫기를 입힌다. 앱 전반에 한 번
/// (`RootView`) 부착해 두면 어느 화면에서 `showLive()`를 불러도 같은 토스트가 뜬다.
private struct LiveToastOverlay: ViewModifier {
    let center: ToastCenter

    /// 이 오버레이의 신원 — 여러 곳(루트·시트)에 붙어도 맨 위 하나만 그리게 하는 열쇠.
    /// `@State`라 뷰가 다시 만들어져도 같은 값을 유지한다.
    @State private var hostID = UUID()

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            // 시트가 떠 있으면 그 시트의 오버레이만 그린다 — 루트 것까지 그리면 `.large`
            // 시트 위쪽 틈으로 삐져나와 토스트가 둘로 보인다.
            if center.isPresented, center.shouldRender(host: hostID) {
                LiveToastView(text: center.message)
                    .padding(.top, Spacing.sm)
                    // 상단에서 내려오고(올라가고) 페이드.
                    .transition(.move(edge: .top).combined(with: .opacity))
                    // 위로 미는 제스처로 즉시 닫기.
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onEnded { value in
                                if value.translation.height < 0 { center.dismiss() }
                            }
                    )
                    // 프리미엄 토스트만 탭으로 페이월 진입 — 일반 토스트는 탭 무반응 유지.
                    .onTapGesture { center.handleTap() }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: center.isPresented)
        .onAppear { center.registerHost(hostID) }
        .onDisappear { center.unregisterHost(hostID) }
    }
}

extension View {
    /// 앱 상단 라이브 토스트 오버레이를 부착한다 — 표시는 주어진 `ToastCenter`가 제어한다.
    func liveToastOverlay(_ center: ToastCenter) -> some View {
        modifier(LiveToastOverlay(center: center))
    }
}
