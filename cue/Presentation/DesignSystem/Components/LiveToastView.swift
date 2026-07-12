//
//  LiveToastView.swift
//  cue / Presentation
//

import SwiftUI

/// 라이브 액티비티가 켜졌음을 알리는 앱 공통 토스트의 *내용*.
///
/// 앞쪽 원형 점에서 바깥으로 번지는 펄스(`FloatingMessageButton`의 on-air 번짐과 같은
/// 시간기반 방식) + "라이브" 라벨을, 옆으로 둥근 캡슐(타원)로 감싼다. 색은 accent(tint)가
/// 아니라 `.primary`(라이트=검정 / 다크=하양 적응). 표시·상단 슬라이드·자동 해제는
/// `ToastCenter` + `liveToastOverlay`가 맡고, 이 뷰는 모양만 그린다.
struct LiveToastView: View {
    /// 캡슐 안 라벨 — 새로 켜면 "라이브", 다시 눌러 재시작하면 "새로고침", 유료 안내는 "Premium".
    let text: String

    var body: some View {
        HStack(spacing: Spacing.smd) {
            liveDot
            Text(text)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, Spacing.smd + Spacing.xxs)
        .padding(.horizontal, Spacing.lg)
        // 불투명 채움 + 테두리 + 그림자 — FloatingMessageButton과 같은 솔리드 캡슐 질감.
        .background(Capsule().fill(.thickMaterial))
        .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 1))
        .clipShape(.capsule)
        .shadow(color: .primary.opacity(0.22), radius: Spacing.sm, y: Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Live on")
    }

    /// 앞쪽 원형 점 — 채워진 작은 원에서 바깥으로 번지는 펄스 링. 위치 이동에 흔들리지 않도록
    /// `.animation(repeatForever)` 대신 `TimelineView`로 시간에서 scale·opacity만 계산한다
    /// (FloatingMessageButton.pulseRing과 같은 이유). 색은 `.primary`(검정/하양 계열).
    private var liveDot: some View {
        ZStack {
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let phase = elapsed.truncatingRemainder(dividingBy: Self.pulsePeriod) / Self.pulsePeriod
                Circle()
                    .stroke(.primary, lineWidth: 1.5)
                    .scaleEffect(1 + 1.2 * phase)
                    .opacity((1 - phase) * 0.6)
            }
            Circle().fill(.primary)
        }
        .frame(width: Spacing.smd, height: Spacing.smd)
    }

    /// 펄스 한 사이클(초) — 점 가장자리에서 시작해 이 시간 동안 퍼지며 사라진다.
    private static let pulsePeriod: Double = 1.6
}

#Preview {
    VStack(spacing: 20) {
        LiveToastView(text: "Live")
        LiveToastView(text: "Refreshed")
        LiveToastView(text: "Premium")
    }
    .padding()
}
