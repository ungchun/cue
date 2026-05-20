---
참조: [docs/tdd.md, docs/coding/swiftui.md, docs/coding/persistence.md]
---

# 테스트 작성

## 무엇을 테스트하나

| 대상 | 어떻게 |
|---|---|
| **UseCase** | 가장 중요. 비즈니스 규칙(검증 등)을 직접 검증. `InMemoryItemRepository` 주입 |
| **Repository 구현** | SwiftData 구현은 인메모리 컨테이너로 — `ModelContainerFactory.make(inMemory: true)` |
| **ViewModel** | 상태 전이를 검증. 인메모리 의존성 또는 `Dependencies.preview` 주입 |
| View (SwiftUI) | 단위 테스트 대상 아님. 동작은 ViewModel 테스트로 검증 |

## 원칙

- **의존성은 인메모리로 치환한다.** 테스트는 디스크·iCloud·네트워크를 건드리지 않는다.
  `InMemoryItemRepository`(actor)가 그 용도다.
- 테스트는 **빠르고 결정적**이어야 한다 (실제 시간·랜덤·전역 상태 의존 금지).
- 해피 경로뿐 아니라 **실패 경로**(검증 실패, `notFound` 등)도 테스트한다.

## 에이전트 주의

- ⚠️ **테스트 과잉 생성 경계.** 같은 경로를 반복 검증하는 테스트를 많이 만들지 않는다.
  테스트 코드량이 프로덕션 코드량을 크게 넘지 않게 한다.
- ⚠️ **테스트 자체의 정확성**은 새 세션 2~3회로 교차 검증한다 → [tdd.md](tdd.md).
- ⚠️ green 단계에서는 **전체 테스트**를 돌린다.

## 도구

테스트 타깃은 `cueTests/`. 빌드·실행은 사용자가 한다 (에이전트는 테스트 *코드*까지만).
