# AGENTS.md — cue

SwiftUI 기반 iOS 앱. 클린 아키텍처 3계층, 로컬 + iCloud 저장, 외부 서버 없음.

이 파일은 **얇은 인덱스**다 — 상세 규칙은 링크된 문서로 위임한다. 내용을 여기 쌓지 않는다.

> `CLAUDE.md`는 이 파일의 심볼릭 링크다. 편집은 `AGENTS.md`만 한다.

## 🔴 최우선 규칙: TDD

**실패하는 테스트 없이 프로덕션 코드 한 줄도 수정/추가하지 않는다.**
모든 코드 변경은 `red → green → refactor → green` 사이클을 따른다.
→ [docs/tdd.md](docs/tdd.md)

## 작업 시작 전

1. **항상 읽기**: 이 파일 + [docs/tdd.md](docs/tdd.md)
2. **작업 유형별 진입점** — 하나를 골라 따른다:

   | 유형 | 문서 |
   |---|---|
   | 새 기능 | [docs/workflow/feature.md](docs/workflow/feature.md) |
   | 버그 수정 | [docs/workflow/bugfix.md](docs/workflow/bugfix.md) |
   | 리팩토링 | [docs/workflow/refactor.md](docs/workflow/refactor.md) |

3. **작업 영역 문서** — 건드리는 영역만 골라 읽는다:

   | 영역 | 문서 |
   |---|---|
   | 계층 구조·의존성 규칙 | [ARCHITECTURE.md](ARCHITECTURE.md) |
   | Swift 스타일·네이밍·에러 | [docs/coding/conventions.md](docs/coding/conventions.md) |
   | SwiftUI·MVVM·동시성 | [docs/coding/swiftui.md](docs/coding/swiftui.md) |
   | SwiftData·iCloud 저장 | [docs/coding/persistence.md](docs/coding/persistence.md) |
   | 테스트 작성 | [docs/testing.md](docs/testing.md) |
   | 계층별 세부 | `cue/{Domain,Data,Presentation}/README.md` |

## 핵심 규칙 (요약 — 상세는 위 문서)

- 의존성은 항상 `Domain`을 향한다. `Domain`은 `SwiftUI`·`SwiftData`를 import하지 않는다.
- 구체 구현 생성은 `App/CompositionRoot.swift`에서만.
- 1 파일 = 1 타입. 역할 접미사(`...UseCase`, `...ViewModel` 등).
- 빌드는 사용자가 직접 수행한다. 에이전트는 코드 변경 후 빌드를 사용자에게 넘긴다.

## 문서 규약

- `docs/`의 각 문서 상단 frontmatter에 `참조:` — 이 문서가 의존하는 다른 문서.
- 한 문서 ~150줄 이내. 초과하면 하위 문서로 분해.
- 규칙에는 "왜"를 함께 적는다.
- 루트(이 파일)는 내용이 아니라 링크. 얇게 유지한다.

## 환경

Xcode 26.5 / Swift 6.0 / iOS 26.0 / Bundle ID `azhy.cue`.

> 앱 컨셉 확정 후 도메인 문서(`docs/domain/`)가 추가된다.
> 현재 `Item`/`ItemList`는 구조 예시(placeholder)다.
