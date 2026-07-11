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

    /// 물결 에코( ( ( ( )가 퍼지는 파동 — 중심을 배너 오른쪽 밖에 두고, 두툼한 초승달
    /// 밴드(굵은 스트로크 원)가 안에서 밖으로 계속 번져 나간다. 정적인 ((( 무늬에
    /// 라이브 펄스의 시간 위상만 입힌 것(TimelineView, 위치 애니메이션 없음).
    private var pulseWaves: some View {
        let base: CGFloat = 90
        return TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            ZStack {
                // 밴드 4장이 위상차를 두고 확장 — 항상 ((( 겹이 유지된 채 퍼져 보인다.
                ForEach(0..<4, id: \.self) { index in
                    let phase = ((elapsed / Self.pulsePeriod) + Double(index) / 4)
                        .truncatingRemainder(dividingBy: 1)
                    Circle()
                        .stroke(Color(.systemBackground), lineWidth: 12)
                        .frame(width: base, height: base)
                        .scaleEffect(0.4 + 2.4 * phase)
                        .opacity((1 - phase) * 0.28)
                }
            }
        }
        .frame(width: base, height: base)
        // 파동 중심을 오른쪽 모서리 밖으로 — 왼쪽 호( ( ( ()만 배너 안에 보인다.
        .offset(x: base * 0.55)
    }

    /// 파동 한 사이클(초) — 느긋하게 번진다.
    private static let pulsePeriod: Double = 3.2
}

#Preview {
    PremiumBannerView(action: {})
        .padding()
}
