//
//  FloatingMessageButton.swift
//  cue / Presentation
//

import SwiftUI

/// 일정·할일 헤더 오른쪽 끝의 라이브 메시지 버튼.
///
/// 위로 향하는 화살표 심볼 + "켜기" 라벨을 옆으로 둥근 캡슐(타원)로 감싸고, 켜져 있음을
/// 알리는 on-air 펄스(바깥으로 번지는 캡슐 외곽선)를 두른다. 동작은 추후 연결(placeholder).
///
/// 탭하면 심볼 펄스 한 번 재생 후 **3초간 쿨다운** — 그동안 번짐은 멈추고, 글자는
/// disabled 톤으로 흐려지며, 실제로 버튼이 비활성화돼 다시 눌리지 않는다.
struct FloatingMessageButton: View {
    /// on-air 번짐(캡슐 외곽선 확산) 반복 구동 플래그. onAppear에서 true로 켜 애니메이션 시작.
    @State private var pulse = false
    /// 탭할 때마다 +1 — 심볼 펄스 이펙트를 다시 재생시키는 트리거.
    @State private var tapCount = 0
    /// 탭 직후 3초 쿨다운 — true면 번짐 멈춤·글자 흐려짐·버튼 비활성.
    @State private var isCoolingDown = false

    private static let cooldown: Duration = .seconds(3)

    var body: some View {
        Button {
            guard !isCoolingDown else { return }
            tapCount += 1
            startCooldown()
            // TODO: 라이브 액티비티 켜기 연결 (현재 placeholder — 동작 없음).
        } label: {
            HStack(spacing: Spacing.smd) {
                Image(systemName: "arrow.turn.left.up")
                    // 텍스트(title3)보다 한 단계 큰 아이콘 — 버튼에서 화살표가 또렷하게.
                    .font(.title2.weight(.bold))
                    .symbolEffect(.pulse, value: tapCount)
                Text("켜기")
            }
            .font(.title3.weight(.bold))
            // 쿨다운 동안 글자·아이콘을 secondary 톤으로 — disabled 느낌.
            .foregroundStyle(isCoolingDown ? Color.secondary : Color.primary)
            // 위아래·좌우 패딩 동일(14 = smd+xxs) — 사방으로 여유 있는 타원.
            .padding(Spacing.smd + Spacing.xxs)
            // 리퀴드 글래스 대신 불투명한 채움 + 테두리 + 그림자 — 솔리드한 "누르고 싶은"
            // 버튼 질감. thickMaterial로 더 또렷하게(덜 비치게). 그림자는 primary 기반이라
            // 라이트=드롭섀도, 다크=은은한 글로우로 적응.
            .background(Capsule().fill(.thickMaterial))
            .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 1))
            .clipShape(.capsule)
            // 번지는 링은 clip **뒤**(아래)에 둔다 — clipShape가 캡슐 밖으로 번지는 링까지
            // 잘라 안 보이던 버그 수정. 채움 뒤라 캡슐 밖으로 나온 부분만 보인다.
            .background(pulseRing)
            .shadow(color: .primary.opacity(0.28), radius: Spacing.xs, y: Spacing.xxs)
        }
        .buttonStyle(.plain)
        .disabled(isCoolingDown)
        .accessibilityLabel("라이브 메시지 켜기")
    }

    /// 켜짐(on-air)을 알리는 번짐 — 절반 주기 어긋난 두 캡슐 외곽선이 바깥으로 퍼지며
    /// 페이드아웃을 반복한다. 음수 패딩으로 사방 동일한 절대 거리만큼 커진다(scaleEffect는
    /// 가로 긴 캡슐에서 좌우가 더 멀리 퍼져 불균일). 쿨다운 동안엔 숨겨 멈춘다.
    ///
    /// 각 링의 `onAppear`에서 `pulse`를 켠다 — 최초 등장은 물론, 쿨다운으로 숨겼다 다시
    /// 나타날 때도 onAppear가 재호출돼 애니메이션이 다시 시작된다.
    @ViewBuilder
    private var pulseRing: some View {
        if !isCoolingDown {
            ForEach(0..<2, id: \.self) { index in
                Capsule()
                    .stroke(.primary, lineWidth: 2)
                    .padding(pulse ? -(Spacing.sm + Spacing.xxs) : Spacing.zero)
                    .opacity(pulse ? 0 : 0.6)
                    .animation(
                        .easeOut(duration: 5.0)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 2.5),
                        value: pulse
                    )
                    .onAppear { pulse = true }
            }
        }
    }

    /// 3초 쿨다운 시작 — 번짐을 즉시 멈추고(`pulse=false`) 버튼을 비활성화한다. 끝나면
    /// 다시 활성화되고, pulseRing이 재등장하며 onAppear가 번짐을 재개한다.
    private func startCooldown() {
        pulse = false
        isCoolingDown = true
        Task {
            try? await Task.sleep(for: Self.cooldown)
            isCoolingDown = false
        }
    }
}

#Preview {
    FloatingMessageButton()
}
