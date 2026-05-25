---
참조: [docs/coding/swiftui.md]
---

# 디자인 시스템

위치: `cue/Presentation/DesignSystem/`. 두 영역으로 나뉜다:

```
DesignSystem/
├── Foundation/   간격 토큰 (색·폰트는 Apple 시스템 그대로 사용)
└── Components/   커스텀 컴포넌트 (필요할 때만 생성)
```

## 🔴 전 모드 공통 규칙

뷰를 그릴 때 모든 모드(feat / fix / refactor)가 반드시 지킨다:

1. **색·폰트는 Apple 시스템 그대로.** 폰트는 SwiftUI 텍스트 스타일(`.body`, `.callout`,
   `.headline`, `.title2`, `.largeTitle.bold()` 등) 직접 사용, 간격은 `Spacing` 토큰만.
   raw 숫자·hex·OKLCH·이름 지은 커스텀 색 리터럴, `.system(size:)` 고정 크기는 **금지**.
2. **iOS 퍼스트파티 컴포넌트 우선.** 뷰는 웬만하면 Apple 기본 컴포넌트
   (`List`, `Button`, `NavigationStack`, `Form`, `Label`…)로 그린다.
3. **커스텀 뷰는 컴포넌트화.** 퍼스트파티로 안 되는 게 진짜 있을 때만 커스텀을 만들되,
   - 반드시 **컴포넌트 단위**로 만들어 `DesignSystem/Components/`에 둔다.
   - 그 컴포넌트 단위로 재사용한다 (Feature 안에 일회용 커스텀 뷰를 두지 않는다).
   - ⚠️ **커스텀 컴포넌트를 만들기 전에 반드시 사용자에게 먼저 알리고 합의한다.**

## Foundation — 색 (Apple 시스템 컬러)

자체 색 토큰을 두지 않는다. **SwiftUI가 제공하는 semantic 컬러만** 쓴다.
이유: iOS 디자인 언어와 자동으로 일치하고, 라이트/다크·Dynamic Type·접근성
대비 모드를 시스템이 알아서 처리한다.

| 용도 | 쓰는 값 | 비고 |
|---|---|---|
| 본문 텍스트 | `.primary` / `Color.primary` | 라이트=검정·다크=흰색 자동 |
| 보조 텍스트·아이콘 | `.secondary` / `Color.secondary` | 흐린 회색 |
| 더 흐린 보조 | `.tertiary` | 거의 안 쓰지만 필요할 때 |
| 강조 (링크·active 상태·체크) | `.tint` / `Color.accentColor` | Assets `AccentColor`가 결정, 미지정 시 시스템 블루 |
| 오류·경고·파괴 액션 | `Color.red` | 시스템 레드 (다크 자동 대응) |
| 그 외 의미 색 | `Color.green`, `Color.orange`, `Color.yellow`, … | 모두 시스템 시맨틱 |

**원칙:**
- `.foregroundStyle(.primary)` / `.foregroundStyle(.secondary)` / `.foregroundStyle(.tint)` 형태가 1순위.
- 삼항 같은 곳에서 ShapeStyle 타입이 안 맞아 컴파일 안 되면 `Color.primary` / `Color.secondary` / `Color.accentColor` / `Color.red`로 통일.
- 배경·구분선은 가능한 한 시스템이 그리는 그대로 둔다 (`Form`/`List`/`Section`의 기본 그룹 배경, `Divider` 등). 명시적 배경이 필요하면 `Color(.systemBackground)` / `Color(.secondarySystemBackground)` 같은 `UIColor` 시맨틱 래퍼를 쓴다.
- 투명도 변형(`Color.primary.opacity(0.08)` 같은 미세 하이라이트)은 OK — 다른 raw 색을 새로 만들지 않는 한 시스템 컬러의 파생으로 본다.

**금지:**
- 자체 색 토큰 enum/struct 정의 (`AppColor`·`ColorPalette` 같은 것 다시 만들지 않는다).
- hex·OKLCH·RGB 리터럴 (`Color(red: ..., green: ..., blue: ...)`, `Color("#FF00AA")`).
- Assets에 색 등록 → `Color("MyBlue")` (예외: 앱 전체 accent는 Assets의 `AccentColor` 하나만).

브랜드 색이 정해지면 Assets의 `AccentColor` 하나만 갱신 → `.tint`로 쓰는 모든 곳이 따라온다.

## Foundation — 타이포그래피 (Apple 시스템 텍스트 스타일)

자체 폰트 토큰을 두지 않는다. **SwiftUI가 제공하는 텍스트 스타일을 그대로** 쓴다 —
모두 Dynamic Type(사용자 접근성 글자 크기)에 자동 대응한다.

| 용도 | 쓰는 값 |
|---|---|
| 화면 최상단 큰 제목 | `.largeTitle.bold()` 또는 `.largeTitle` |
| 섹션 제목 | `.title2.weight(.semibold)` |
| 하위 제목 | `.title3.weight(.semibold)` |
| 강조 본문 / 행 헤더 | `.headline` |
| 기본 본문 | `.body` |
| 보조 본문 / 행 메타 | `.callout` |
| 캡션 (작게, 보조) | `.subheadline` / `.footnote` |
| 가장 작은 캡션 | `.caption` / `.caption2` |

- 사용: `.font(.body)`, `.font(.callout)`, `.font(.title2.weight(.semibold))` 식 직접.
- weight 변형이 필요하면 `.body.weight(.medium)`처럼 SwiftUI Font modifier로.
- 고정 크기 `.system(size:)`는 접근성 글자 크기를 깨므로 **금지**.
- 자체 폰트 토큰 enum(`AppFont` 등)을 다시 만들지 않는다.

## Foundation — 간격 (Spacing)

4/8pt 그리드. `Spacing.xxs`(2) ~ `Spacing.xxl`(48).

- 사용: `.padding(Spacing.md)`.

## Components — 커스텀 컴포넌트

- 위치: `DesignSystem/Components/`. 파일 1개 = 컴포넌트 1개.
- 생성 조건: 퍼스트파티로 불가능 + 재사용 가치 있음 + **사용자 합의 완료**.
- 컴포넌트도 내부에서 시스템 컬러 + Apple 텍스트 스타일 + `Spacing`만 쓴다.

## 토큰·컴포넌트 추가하기

- 새 글꼴 토큰은 **추가하지 않는다** — SwiftUI 시스템 텍스트 스타일 안에서 표현한다.
- 새 간격 → `Spacing`에 추가 (4/8pt 그리드 유지).
- 새 색은 **추가하지 않는다** — 시스템 시맨틱 컬러로 표현 못 하는 의미가 생기면 먼저 사용자와 합의.
- 새 컴포넌트 → **사용자 합의 후** `Components/`에 추가.
