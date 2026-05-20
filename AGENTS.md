# AGENTS.md — cue

AI 코딩 에이전트를 위한 안내. 작업 전 이 문서와 `ARCHITECTURE.md`를 먼저 읽는다.

## 프로젝트 개요

- **cue** — SwiftUI 기반 iOS 앱. 클린 아키텍처 3계층.
- 외부 서버 없음. 저장은 **로컬 + iCloud(CloudKit)**.
- Xcode 26.5 / Swift 5 언어 모드 / iOS 26.5 타깃 / Bundle ID `azhy.cue`.
- ⚠️ `Item` 관련 코드는 **구조 예시(placeholder)**. 실제 앱 컨셉이 정해지면 교체 대상.

## 빌드 / 실행

```bash
# 빌드 (시뮬레이터)
xcodebuild -project cue.xcodeproj -scheme cue \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# 테스트
xcodebuild -project cue.xcodeproj -scheme cue \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

프로젝트는 Xcode 동기화 그룹(objectVersion 77)을 쓴다 — `cue/` 폴더에
파일을 추가하면 Xcode가 자동으로 타깃에 포함한다 (.pbxproj 수동 편집 불필요).

## 계층 규칙 (필수 준수)

의존성은 항상 `Domain`을 향한다. 자세한 내용은 `ARCHITECTURE.md`.

| 계층 | import 허용 | import 금지 |
|---|---|---|
| `Domain/` | `Foundation`만 | `SwiftUI`, `SwiftData` ❌ |
| `Data/` | `Foundation`, `SwiftData`, `Domain` 타입 | `SwiftUI` ❌ |
| `Presentation/` | `SwiftUI`, `Domain` 타입 | `SwiftData` ❌, `Data` 타입 ❌ |
| `App/` | 전부 (조립 담당) | — |

- `@Model` 클래스(`Data`)는 계층 밖으로 노출 금지 → 항상 `...Mapper`로 도메인 엔티티 변환.
- 구체 구현 생성은 `App/CompositionRoot.swift`에서만.

## 네이밍 규칙

- **1 파일 = 1 타입**, 파일명 = 타입명.
- 역할 접미사: `...UseCase`, `...Repository`(프로토콜), `SwiftData...Repository`(구현),
  `...Model`(@Model), `...ViewModel`(@Observable), `...View`, `...Mapper`, `...Route`.
- `Presentation/Features/`는 **기능 단위 폴더** — View + ViewModel을 한 폴더에.

## 작업 시 주의

- 새 `@Model` 추가 → `ModelContainerFactory.schema` 배열에 등록.
- SwiftData + CloudKit 제약(유니크 금지, 옵셔널/기본값 필수 등)은
  `Data/Persistence/Models/ItemModel.swift` 주석 참고.
- ViewModel은 `@MainActor @Observable final class`, `init(dependencies:)`로 생성.
- 빌드는 사용자가 직접 수행한다 — 에이전트는 코드 변경 후 사용자에게 빌드를 넘긴다.
