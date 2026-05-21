---
참조: [docs/tdd.md, docs/testing.md, docs/coding/swiftui.md, docs/design-system.md, ARCHITECTURE.md]
---

# 워크플로우 — feat (새 기능)

새 동작을 추가한다. **계획을 완벽히 세운 뒤** [TDD 사이클](../tdd.md)을 거친다.

사이클: `plan → red → green → refactor → green`

## plan (코드 손대기 전 — 필수)

작업에 들어가기 전 계획을 세우고 사용자와 합의한다. 두 부분:

1. **enrich** — 요청을 명확해질 때까지 구체화한다. 모호한 점·열린 질문을 끌어낸다.
2. **plan** — 구현 계획: 무엇을 · 어느 계층에 · 어떤 테스트로 · 어떤 순서로.
   블로커를 미리 드러낸다.

**게이트: 열린 질문이나 블로커가 남아 있으면 red(코드)로 들어가지 않는다.**
사용자와 계획을 합의한 뒤에만 진입한다.

## red → green → refactor → green

1. **red** — 실패하는 테스트 작성. 해피 경로 + 실패 경로 둘 다. → [testing.md](../testing.md)
2. **green** — 통과시키는 최소 구현. 미리 일반화하지 않는다(YAGNI). 전체 테스트 green 확인.
3. **refactor** — View 분리, 중복 추출, 명명 정리. → [refactor.md](refactor.md)
4. **green** — 전체 테스트 재확인.

## 어디에 코드를 두나

[ARCHITECTURE.md](../../ARCHITECTURE.md)의 "어디에 무엇을 두나" 표를 따른다:

- 새 비즈니스 동작 → `Domain/UseCases/`
- 새 화면 → `Presentation/Features/<기능>/` (View + ViewModel)
- 새 저장 필요 → Repository 프로토콜(`Domain`) + 구현(`Data`)

## 뷰를 그릴 때

[design-system.md](../design-system.md)를 따른다 — Foundation 토큰만 사용, 퍼스트파티
컴포넌트 우선, 커스텀 컴포넌트는 **만들기 전 사용자에게 알리고 합의**.

## 완료 조건

- 계획 사용자 합의 완료
- 해피·실패 경로 테스트 모두 green
- 의존성·디자인 시스템 규칙 위반 없음
- 사용자가 빌드·실행으로 확인

커밋: `feat:`
