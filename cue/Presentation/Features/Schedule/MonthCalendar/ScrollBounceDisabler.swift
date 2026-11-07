//
//  ScrollBounceDisabler.swift
//  cue / Presentation
//

import SwiftUI
import UIKit

/// 감싼 SwiftUI `ScrollView`의 고무줄 바운스를 끈다 — 스크롤이 내용 끝에서 딱 멈추게.
///
/// SwiftUI는 바운스를 끄는 API가 없다(`scrollBounceBehavior`는 내용이 짧을 때만 막는다).
/// 스크롤 내용 안에 보이지 않는 UIView를 심어, 창에 붙는 순간 가장 가까운 상위
/// `UIScrollView`만 찾아 `bounces`를 끈다 — 다른 스크롤(월 가로 페이저 등)은 건드리지 않는다.
struct ScrollBounceDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> ProbeView { ProbeView() }

    func updateUIView(_ uiView: ProbeView, context: Context) {}

    final class ProbeView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            var view = superview
            while let current = view {
                if let scrollView = current as? UIScrollView {
                    scrollView.bounces = false
                    return
                }
                view = current.superview
            }
        }
    }
}
