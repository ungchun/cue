//
//  WidgetPremiumLock.swift
//  cueLiveActivity
//
//  프리미엄 위젯을 무료로 쓸 때 덮는 잠금 안내.
//

import SwiftUI

/// 유료 위젯 위에 얹는 잠금 안내.
///
/// 위젯 자체는 그대로 그리고 그 위를 덮는다 — 빈 화면을 띄우면 "무엇을 잃고 있는지"가
/// 안 보여 구독할 이유가 생기지 않는다. 격자와 날짜는 비쳐 보이되 일정·할일만 가린다.
struct WidgetPremiumLock: ViewModifier {
    /// `false`면 아무것도 하지 않는다 — 유료 사용자에게는 이 뷰가 없는 것과 같다.
    let isLocked: Bool

    @Environment(\.colorScheme) private var colorScheme

    /// 격자를 덮는 색 — 위젯 배경과 같은 계열이어야 한 겹 얹힌 것처럼 보인다.
    /// 라이트에서 검정을 깔면 그 부분만 패널처럼 도드라진다.
    private var veil: Color { colorScheme == .dark ? .black : .white }

    /// 안내 글자색 — 덮개와 반대여야 어느 테마에서도 대비가 산다.
    private var ink: Color { colorScheme == .dark ? .white : .black }

    func body(content: Content) -> some View {
        content.overlay {
            if isLocked {
                // 격자는 비쳐 보이게 두되 **한 겹 어둡게** 깐다 — 항목은 이미 비워서
                // 넘어오므로 가릴 내용은 없지만, 격자선 위에 글자가 바로 얹히면 획과
                // 선이 섞여 안 읽힌다. 빈 달력이 보이는 편이 "여기 뭐가 들어갈 자리"임을
                // 말해줘서 통째로 덮는 것보다 구독할 이유가 잘 전달된다.
                ZStack {
                    // 0.7 — 렌더해서 셋(0.4·0.55·0.7)을 비교한 값이다. 이보다 옅으면
                    // 글자 뒤 날짜 숫자가 비쳐 획과 섞이고, 더 진하면 격자가 사라져
                    // "여기 뭐가 들어갈 자리"라는 맥락까지 함께 지워진다.
                    Rectangle().fill(veil.opacity(0.7))
                    VStack(spacing: Spacing.xs) {
                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundStyle(ink.opacity(0.9))
                        Text("Premium widget")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ink)
                        Text("Subscribe to see your events and reminders")
                            .font(.caption2)
                            // 덮개 위에서는 `.secondary`가 배경에 묻힌다 — 글자색을
                            // 직접 낮춰 써야 어느 테마에서도 대비가 유지된다.
                            .foregroundStyle(ink.opacity(0.75))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, Spacing.md)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

extension View {
    /// 프리미엄 위젯을 무료 사용자에게 잠근다.
    func premiumLocked(_ isLocked: Bool) -> some View {
        modifier(WidgetPremiumLock(isLocked: isLocked))
    }
}

/// 위젯 갤러리에 띄울 이름 — 유료 위젯이면 **구독 전에만** 자물쇠를 붙인다.
///
/// `configurationDisplayName`은 위젯 정의가 평가될 때 한 번 정해지는 정적 문자열이라
/// 타임라인처럼 자주 갱신되지 않는다. 다만 그 평가도 위젯 익스텐션 프로세스에서 일어나므로
/// App Group은 읽을 수 있다 — 구독 후 갤러리를 다시 열면 자물쇠가 사라진다.
func widgetGalleryName(_ base: LocalizedStringResource, requiresPremium: Bool) -> String {
    let name = String(localized: base)
    guard requiresPremium, !SharedAppGroup.isPremium else { return name }
    return "\(name) 🔒"
}
