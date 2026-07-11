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
                    ripples
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Spacing.xxl, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// 아이콘의 물결 겹 확대 — 같은 크기의 원을 오른쪽으로 조금씩 밀며 겹쳐,
    /// 겹칠수록 밝아지는 초승달 밴드( ) ) ) )를 만든다. 배너 오른쪽 밖으로 잘려 나간다.
    private var ripples: some View {
        let size: CGFloat = 190
        return ZStack {
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .fill(Color(.systemBackground).opacity(0.10))
                    .frame(width: size, height: size)
                    .offset(x: size * 0.38 + CGFloat(index) * size * 0.11)
            }
        }
    }
}

#Preview {
    PremiumBannerView(action: {})
        .padding()
}
