---
참조: [docs/coding/swiftui.md]
---

# 디자인 시스템

위치: `cue/Presentation/DesignSystem/`. 두 영역으로 나뉜다:

```
DesignSystem/
├── Foundation/   색·타이포그래피·간격 토큰
└── Components/   커스텀 컴포넌트 (필요할 때만 생성)
```

## 🔴 전 모드 공통 규칙

뷰를 그릴 때 모든 모드(feat / fix / refactor)가 반드시 지킨다:

1. **Foundation 토큰만 사용.** 색·글꼴·간격은 `AppColor` · `AppFont` · `Spacing`만
   쓴다. raw 숫자·색 리터럴을 뷰에 직접 입력하는 것은 **절대 금지**.
2. **iOS 퍼스트파티 컴포넌트 우선.** 뷰는 웬만하면 Apple 기본 컴포넌트
   (`List`, `Button`, `NavigationStack`, `Form`, `Label`…)로 그린다.
3. **커스텀 뷰는 컴포넌트화.** 퍼스트파티로 안 되는 게 진짜 있을 때만 커스텀을 만들되,
   - 반드시 **컴포넌트 단위**로 만들어 `DesignSystem/Components/`에 둔다.
   - 그 컴포넌트 단위로 재사용한다 (Feature 안에 일회용 커스텀 뷰를 두지 않는다).
   - ⚠️ **커스텀 컴포넌트를 만들기 전에 반드시 사용자에게 먼저 알리고 합의한다.**

## Foundation — 색 (Color)

색은 **OKLCH로 작성**한다. iOS는 OKLCH 네이티브 미지원이라 `Color.oklch(l, c, h)`가
sRGB로 변환한다 (`Foundation/Color+OKLCH.swift`).

**2-tier 토큰:**

| Tier | 파일 | 뷰에서 |
|---|---|---|
| Primitive 팔레트 | `ColorPalette` (`neutral50`…, `accent500`…) | ❌ 직접 사용 금지 |
| Semantic 토큰 | `AppColor` (`background`, `textPrimary`, `accent`…) | ✅ 이것만 사용 |

- 뷰: `.foregroundStyle(AppColor.textPrimary)`, `.background(AppColor.background)`.
- 라이트/다크 모드는 `AppColor` 토큰이 `Color.dynamic`으로 자동 해석한다.
- 팔레트 변경 → `ColorPalette`의 OKLCH 값만 수정하면 앱 전체가 따라온다.
- ⚠️ 현재 팔레트는 브랜드 색 미정 상태의 placeholder다.

## Foundation — 타이포그래피 (AppFont)

Apple 시스템 텍스트 스타일 위에 의미 이름을 매핑 → Dynamic Type 자동 지원.

- 사용: `.font(AppFont.bodyLarge)`.
- 고정 크기 `.system(size:)`는 접근성 글자 크기를 깨므로 금지.

## Foundation — 간격 (Spacing)

4/8pt 그리드. `Spacing.xxs`(2) ~ `Spacing.xxl`(48).

- 사용: `.padding(Spacing.md)`.

## Components — 커스텀 컴포넌트

- 위치: `DesignSystem/Components/`. 파일 1개 = 컴포넌트 1개.
- 생성 조건: 퍼스트파티로 불가능 + 재사용 가치 있음 + **사용자 합의 완료**.
- 컴포넌트도 내부에서 Foundation 토큰만 쓴다.

## 토큰·컴포넌트 추가하기

- 새 색 → `ColorPalette` primitive 추가 → `AppColor` semantic 추가.
- 새 글꼴 → `AppFont`에 추가 (반드시 시스템 텍스트 스타일 기반).
- 새 컴포넌트 → **사용자 합의 후** `Components/`에 추가.
