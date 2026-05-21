---
참조: [ARCHITECTURE.md, docs/coding/conventions.md]
---

# SwiftUI · MVVM · 동시성

## MVVM 패턴

- 화면 1개 = `Presentation/Features/<기능>/`에 `...View` + `...ViewModel`.
- **ViewModel**: `@MainActor @Observable final class`.
  - `init(dependencies: Dependencies)`로 생성. 필요한 UseCase만 보관한다.
  - `SwiftUI`를 import하지 않는다 (상태·동작만 — 순수 로직, 테스트 가능).
- **View**: 상태를 직접 갖지 않고 ViewModel에 위임한다.
  - ViewModel은 `@State`로 보유, `init`에서 `State(initialValue:)`로 생성.
- View가 비대해지면 하위 View로 분리한다.

## 의존성 주입 (DI)

- 구체 구현 생성은 `App/CompositionRoot.swift` **한 곳**에서만.
- `Dependencies` 묶음을 `@Environment(\.dependencies)`로 주입한다.
- ViewModel은 전역 싱글톤이 아니라 `init`으로 의존성을 받는다 (테스트 가능하게).

## Swift 동시성

- **프로젝트 기본 액터 격리는 `nonisolated`** (`SWIFT_DEFAULT_ACTOR_ISOLATION`).
  순수 타입(Domain 엔티티·enum 등)은 격리 없음이 기본 — UI(`View`·`ViewModel`·
  `CompositionRoot`)는 `@MainActor`를 **명시**한다. `MainActor` 기본값은 순수
  Domain 계층·`actor`·테스트와 충돌하므로 쓰지 않는다 (SE-0466).
- Repository **프로토콜**은 `Sendable`, 메서드는 `async throws`.
- SwiftData를 쓰는 구현은 `@MainActor` (메인 `ModelContext` 사용).
- 인메모리·순수 구현은 `actor`로 격리한다.
  - `@Entry` 환경 기본값에서 참조되는 값은 메인 액터 격리에 걸리지 않게 둔다.
    그래서 `InMemoryItemRepository`가 `actor`다 (과거 이 문제로 컴파일이 막혔음).
- 동기 메서드는 `async` 프로토콜 요구사항을 충족할 수 있다.

## 네비게이션

- 경로는 `Navigation/AppRoute`(enum), 상태는 `AppRouter`(`@Observable`).
- 새 화면 → `AppRoute`에 case + `destination` 추가.
