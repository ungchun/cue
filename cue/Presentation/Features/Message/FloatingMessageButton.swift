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
    /// 탭 시 실행할 동작 — 라이브 액티비티 토글(시작/종료)을 호출처(ViewModel)가 주입한다.
    let action: () async -> Void

    /// 탭할 때마다 +1 — 심볼 펄스 이펙트를 다시 재생시키는 트리거.
    @State private var tapCount = 0
    /// 탭 직후 3초 쿨다운 — true면 번짐 멈춤·글자 흐려짐·버튼 비활성.
    @State private var isCoolingDown = false
    /// 호출처의 `.disabled(_:)` 반영 — false면 dim + 번짐 정지(메모: 입력 없을 때 등).
    @Environment(\.isEnabled) private var isEnabled

    private static let cooldown: Duration = .seconds(3)

    /// 쿨다운이거나 비활성이면 흐리게/멈춤 — disabled 시각.
    private var isDimmed: Bool { isCoolingDown || !isEnabled }

    var body: some View {
        Button {
            guard !isCoolingDown else { return }
            tapCount += 1
            startCooldown()
            Task { await action() }
        } label: {
            HStack(spacing: Spacing.smd) {
                Image(systemName: "arrow.turn.left.up")
                    // 텍스트(title3)보다 한 단계 큰 아이콘 — 버튼에서 화살표가 또렷하게.
                    .font(.title2.weight(.bold))
                    .symbolEffect(.pulse, value: tapCount)
                Text("켜기")
            }
            .font(.title3.weight(.bold))
            // 쿨다운·비활성이면 글자·아이콘을 secondary 톤으로 — disabled 느낌.
            .foregroundStyle(isDimmed ? Color.secondary : Color.primary)
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
            // 그림자 2겹 — 아래로 떨어지는 또렷한 드롭 + 사방으로 번지는 부드러운 글로우.
            // 둘 다 primary 기반이라 라이트=그림자, 다크=발광으로 적응하며 입체감을 강조한다.
            .shadow(color: .primary.opacity(0.35), radius: Spacing.sm, y: Spacing.xs)
            .shadow(color: .primary.opacity(0.18), radius: Spacing.md)
        }
        .buttonStyle(.plain)
        .disabled(isCoolingDown)
        .accessibilityLabel("라이브 메시지 켜기")
    }

    /// 켜짐(on-air)을 알리는 번짐 — 버튼과 똑같은 캡슐을 버튼 가장자리(scale 1)에서 시작해
    /// 살짝 키우며(scale 1.12) 페이드아웃한다.
    ///
    /// **시간 기반(`TimelineView`)**으로 그린다 — `.animation(repeatForever)` 같은 암시적
    /// 애니메이션을 쓰면, 메모처럼 입력에 따라 버튼이 이동하는 레이아웃에서 그 애니메이션이
    /// 버튼의 *위치 이동*까지 캡처해 펄스가 대각선에서 날아오거나 어긋났다. 시간에서 scale·
    /// opacity만 계산하고 위치는 매 프레임 레이아웃 그대로 따라가므로, 버튼이 어떻게 움직이든
    /// 펄스는 항상 버튼에 딱 붙는다. 쿨다운/비활성 동안엔 숨겨 멈춘다.
    @ViewBuilder
    private var pulseRing: some View {
        if !isDimmed {
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let phase = elapsed.truncatingRemainder(dividingBy: Self.pulsePeriod) / Self.pulsePeriod
                Capsule()
                    .stroke(.primary, lineWidth: 1.5)
                    .scaleEffect(1 + 0.12 * phase)
                    .opacity((1 - phase) * 0.5)
            }
        }
    }

    /// 펄스 한 사이클(초) — 버튼 가장자리에서 시작해 이 시간 동안 퍼지며 사라진다.
    private static let pulsePeriod: Double = 2.2

    /// 3초 쿨다운 시작 — 버튼을 비활성화한다. 쿨다운 동안 `isDimmed`가 참이라 pulseRing이
    /// 숨겨져 번짐이 멈추고, 끝나면 다시 나타나 재개된다.
    private func startCooldown() {
        isCoolingDown = true
        Task {
            try? await Task.sleep(for: Self.cooldown)
            isCoolingDown = false
        }
    }
}

#Preview {
    FloatingMessageButton {}
}
