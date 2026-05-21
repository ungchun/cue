# AGENTS.md — cue

**cue** — "지금 잊으면 안 되는 하나"를 잠금화면·Dynamic Island·Live Activity에
띄워두는 신호 앱. 전체 컨셉 → [docs/concept.md](docs/concept.md)

SwiftUI 기반, 클린 아키텍처 3계층, 로컬 + iCloud 저장, 외부 서버 없음.

이 파일은 **얇은 인덱스**다 — 상세 규칙은 링크된 문서로 위임한다. 내용을 여기 쌓지 않는다.

> `CLAUDE.md`는 이 파일의 심볼릭 링크다. 편집은 `AGENTS.md`만 한다.

## 🔴 최우선 규칙: TDD

**실패하는 테스트 없이 프로덕션 코드 한 줄도 수정/추가하지 않는다.**
모든 코드 변경은 `red → green → refactor → green` 사이클을 따른다.
→ [docs/tdd.md](docs/tdd.md)

## 작업 시작 전

1. **항상 읽기**: 이 파일 + [docs/tdd.md](docs/tdd.md)
2. **작업 유형별 진입점** — `/cue` 스킬이 분류·라우팅을 자동화한다. 직접 할 땐 하나 골라 따른다:

   | 모드 | 문서 |
   |---|---|
   | feat (새 기능) | [docs/workflow/feat.md](docs/workflow/feat.md) |
   | fix (버그 수정) | [docs/workflow/fix.md](docs/workflow/fix.md) |
   | refactor (리팩토링) | [docs/workflow/refactor.md](docs/workflow/refactor.md) |
   | debug (원인 진단) | [docs/workflow/debug.md](docs/workflow/debug.md) |

3. **작업 영역 문서** — 건드리는 영역만 골라 읽는다:

   | 영역 | 문서 |
   |---|---|
   | 앱 컨셉·제품 | [docs/concept.md](docs/concept.md) |
   | 계층 구조·의존성 규칙 | [ARCHITECTURE.md](ARCHITECTURE.md) |
   | Swift 스타일·네이밍·에러 | [docs/coding/conventions.md](docs/coding/conventions.md) |
   | SwiftUI·MVVM·동시성 | [docs/coding/swiftui.md](docs/coding/swiftui.md) |
   | 디자인 시스템 (색·타이포·간격) | [docs/design-system.md](docs/design-system.md) |
   | SwiftData·iCloud 저장 | [docs/coding/persistence.md](docs/coding/persistence.md) |
   | 테스트 작성 | [docs/testing.md](docs/testing.md) |
   | 계층별 세부 | [domain](docs/layers/domain.md) · [data](docs/layers/data.md) · [presentation](docs/layers/presentation.md) |

## 핵심 규칙 (요약 — 상세는 위 문서)

- 의존성은 항상 `Domain`을 향한다. `Domain`은 `SwiftUI`·`SwiftData`를 import하지 않는다.
- 구체 구현 생성은 `App/CompositionRoot.swift`에서만.
- 1 파일 = 1 타입. 역할 접미사(`...UseCase`, `...ViewModel` 등).
- 뷰는 디자인 시스템 토큰(`AppColor`/`AppFont`/`Spacing`)만 — raw 값 직접 입력 금지, 퍼스트파티 컴포넌트 우선.
- 빌드는 사용자가 직접 수행한다. 에이전트는 코드 변경 후 빌드를 사용자에게 넘긴다.

## 문서 규약

- `docs/`의 각 문서 상단 frontmatter에 `참조:` — 이 문서가 의존하는 다른 문서.
- 한 문서 ~150줄 이내. 초과하면 하위 문서로 분해.
- 규칙에는 "왜"를 함께 적는다.
- 루트(이 파일)는 내용이 아니라 링크. 얇게 유지한다.

## 환경

Xcode 26.5 / Swift 6.0 / iOS 26.0 / Bundle ID `azhy.cue`.

> 앱 컨셉은 [docs/concept.md](docs/concept.md). 도메인 코드는 추후 `docs/domain/`.
> 현재 `Item`/`ItemList`는 placeholder다 — 실제 도메인(`Cue` 등)으로 교체 예정.
