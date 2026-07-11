//
//  PremiumBannerView.swift
//  cue / Presentation
//
//  설정 최상단의 Cue Premium 배너 — 앱 아이콘의 "물결 겹" 문법을 확대한 에코 장식.
//  다크 캡슐(라이트=검정/다크=하양 반전, `.primary`) 위에 좌측 타이틀·서브카피,
//  우측엔 아이콘 물결을 크게 늘린 초승달 레이어가 배너 밖으로 잘려 나간다.
//  색은 시스템 컬러(.primary / .systemBackground)만 — 아이콘이 무채색이라 가능.
//

import SwiftUI

struct PremiumBannerView: View {
    /// 탭 동작 — 페이월은 추후. 지금은 호출처가 placeholder(토스트)를 넘긴다.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.smd) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Cue Premium")
                        .font(.title.weight(.bold))
                    Text("라이브를 항상, 나답게")
                        .font(.footnote)
                        .opacity(0.75)
                }
                Spacer()
            }
            .foregroundStyle(Color(.systemBackground))
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            // 버튼 자체는 큼직하게 — 내부 패딩과 별개로 최소 높이를 보장한다.
            .frame(minHeight: 104)
            .background {
                ZStack(alignment: .trailing) {
                    Rectangle().fill(.primary)
                    pulseWaves
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Spacing.xxl, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// 라이브 펄스 파동 — 토스트의 라이브 점과 같은 문법을 크게. 가운데 점에서 링이
    /// 계속 번져 나간다(TimelineView 시간 기반, 위치 애니메이션 없음). "라이브가 계속
    /// 살아있다"는 Premium의 핵심 가치를 장식이 직접 말한다.
    private var pulseWaves: some View {
        let size: CGFloat = 56
        return ZStack {
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    // 링 3개가 위상차를 두고 번진다 — 항상 파동이 이어져 보이게.
                    ForEach(0..<3, id: \.self) { index in
                        let phase = ((elapsed / Self.pulsePeriod) + Double(index) / 3)
                            .truncatingRemainder(dividingBy: 1)
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 1.5)
                            .scaleEffect(1 + 2.6 * phase)
                            .opacity((1 - phase) * 0.45)
                    }
                }
            }
            Circle().fill(Color(.systemBackground).opacity(0.9))
                .frame(width: size * 0.22, height: size * 0.22)
        }
        .frame(width: size, height: size)
        .padding(.trailing, Spacing.xl)
    }

    /// 펄스 한 사이클(초) — 토스트(1.6s)보다 느긋하게 번진다.
    private static let pulsePeriod: Double = 2.4
}

#Preview {
    PremiumBannerView(action: {})
        .padding()
}
