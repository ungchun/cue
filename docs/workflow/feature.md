---
참조: [docs/tdd.md, docs/testing.md, docs/coding/swiftui.md, ARCHITECTURE.md]
---

# 워크플로우 — 새 기능

새 기능은 [TDD 사이클](../tdd.md)의 네 단계를 **모두** 거친다.

## 순서

1. **명세** — 무엇을, 어떤 입력 → 출력으로. 화면이라면 상태 전이를 한 줄로 적는다.
2. **red** — 실패하는 테스트 작성. **해피 경로 + 실패 경로** 둘 다.
   대상에 따라 UseCase/Repository/ViewModel 테스트 → [testing.md](../testing.md).
3. **green** — 통과시키는 최소 구현. 전체 테스트 green 확인.
4. **refactor** — View 분리, 중복 추출, 명명 정리 → [refactor.md](refactor.md).
5. **green** — 전체 테스트 재확인.

## 어디에 코드를 두나

기능은 보통 여러 계층에 걸친다. [ARCHITECTURE.md](../../ARCHITECTURE.md)의
"어디에 무엇을 두나" 표를 따른다:

- 새 비즈니스 동작 → `Domain/UseCases/` (`...UseCase`)
- 새 화면 → `Presentation/Features/<기능>/` (View + ViewModel)
- 새 저장 필요 → Repository 프로토콜(`Domain`) + 구현(`Data`)
- 새 SwiftData 모델 → `ModelContainerFactory.schema`에 등록

## 완료 조건

- 해피·실패 경로 테스트 모두 green
- 의존성 규칙 위반 없음 (`Domain`이 `SwiftUI`/`SwiftData` import 안 함)
- 사용자가 빌드·실행으로 확인
