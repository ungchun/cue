---
참조: [ARCHITECTURE.md, docs/coding/swiftui.md]
---

# Presentation 계층

위치: `cue/Presentation/`. SwiftUI UI. `Domain`에만 의존한다 (`Data`를 직접 알지 못한다).

## 폴더
| 폴더 | 담는 것 |
|---|---|
| `Features/<기능명>/` | 화면 1개 = 폴더 1개. `...View` + `...ViewModel` 함께 |
| `Navigation/` | `AppRoute`(경로), `AppRouter`(네비 상태) |
| `DesignSystem/` | 디자인 토큰·공용 컴포넌트 (`Spacing` 등) |

## 패턴: MVVM + `@Observable`
- `...ViewModel`: `@MainActor @Observable final class`. UseCase에만 의존, SwiftUI import 금지.
- `...View`: 상태는 ViewModel에 위임. ViewModel은 `init(dependencies:)`로 생성.
- ViewModel은 UseCase를 통해서만 데이터에 접근한다.

상세 패턴은 [docs/coding/swiftui.md](../coding/swiftui.md) 참고.
