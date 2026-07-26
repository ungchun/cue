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

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if center.isPresented {
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
    }
}

extension View {
    /// 앱 상단 라이브 토스트 오버레이를 부착한다 — 표시는 주어진 `ToastCenter`가 제어한다.
    func liveToastOverlay(_ center: ToastCenter) -> some View {
        modifier(LiveToastOverlay(center: center))
    }
}
