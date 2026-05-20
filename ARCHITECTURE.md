# cue 아키텍처

SwiftUI 기반 iOS 앱. **클린 아키텍처 3계층** + 로컬/iCloud 저장. 외부 서버 없음.

## 계층 모델

```
┌─────────────────┐         ┌─────────────────┐
│  Presentation   │         │      Data       │
│  (SwiftUI/MVVM) │         │ (SwiftData/iCloud)
└────────┬────────┘         └────────┬────────┘
         │   의존              의존    │
         ▼                          ▼
        ┌────────────────────────────┐
        │           Domain           │
        │  (Entity·UseCase·Protocol)  │  ← 아무것도 의존하지 않음
        └────────────────────────────┘
```

**의존성 규칙**: 화살표는 항상 안쪽(Domain)을 향한다.
- `Domain`은 아무것도 의존하지 않는다 (`Foundation`만).
- `Data`와 `Presentation`은 `Domain`에 의존한다.
- `Data`와 `Presentation`은 **서로를 모른다**.
- `App`만 세 계층을 모두 알고, 조립한다.

런타임 데이터는 바깥으로 흐르지만, 컴파일타임 의존성은 안쪽을 향한다 — 이를 가능하게
하는 것이 **의존성 역전**: Repository 프로토콜을 `Domain`이 정의하고 `Data`가 구현한다.

## 폴더 구조 (`cue/`)

```
cue/
├── cueApp.swift            @main 진입점
├── App/                    조립 — 세 계층을 연결
│   ├── CompositionRoot     구체 구현 생성 (유일한 장소)
│   ├── Dependencies        의존성 묶음 + @Environment 키
│   └── RootView            첫 화면 + NavigationStack
├── Domain/                 핵심 규칙 — 의존성 0
│   ├── Entities/           순수 Swift 모델
│   ├── Repositories/       저장소 프로토콜
│   ├── UseCases/           비즈니스 동작
│   └── Errors/             도메인 오류
├── Data/                   Domain 구현 — SwiftData/iCloud
│   ├── Persistence/
│   │   ├── Models/         @Model 클래스
│   │   ├── Mappers/        @Model ↔ Entity 변환
│   │   └── ModelContainerFactory
│   └── Repositories/       Repository 프로토콜 구현
├── Presentation/           SwiftUI UI
│   ├── Features/<기능>/    View + ViewModel (화면 단위)
│   ├── Navigation/         경로·라우터
│   └── DesignSystem/       디자인 토큰
└── Core/                   계층 무관 공용 (로깅 등)
```

## 어디에 무엇을 두나

| 추가하려는 것 | 위치 |
|---|---|
| 새 데이터 개념 (구조체) | `Domain/Entities/` |
| 새 비즈니스 동작 | `Domain/UseCases/` (`...UseCase`) |
| 새 저장소 종류 | 프로토콜 → `Domain/Repositories/`, 구현 → `Data/Repositories/` |
| 새 SwiftData 모델 | `Data/Persistence/Models/` + `ModelContainerFactory.schema`에 등록 |
| 새 화면 | `Presentation/Features/<기능>/` (View + ViewModel) |
| 화면 이동 경로 | `Presentation/Navigation/AppRoute.swift`에 case 추가 |
| 색상·간격 등 토큰 | `Presentation/DesignSystem/` |

## 기술 선택

| 영역 | 선택 | 이유 |
|---|---|---|
| UI 패턴 | MVVM + `@Observable` | Apple 네이티브, 테스트 경계 확보 |
| 저장 | SwiftData + CloudKit | 서버 없이 로컬+iCloud 동기화 |
| DI | `CompositionRoot` + `@Environment` | 서드파티 불필요 |
| 모듈화 | 폴더 그룹 (단일 타깃) | 단순. 향후 SPM 패키지로 승격 가능 |

## 데이터 흐름 (예: 항목 추가)

```
ItemListView → ItemListViewModel → AddItemUseCase
   → ItemRepository(프로토콜) → SwiftDataItemRepository
   → ItemMapper → ItemModel → SwiftData → (iCloud 동기화)
```

## iCloud 동기화

`ModelConfiguration`의 `cloudKitDatabase`가 `.automatic`이라,
Xcode에서 **iCloud → CloudKit** 역량만 추가하면 코드 변경 없이 켜진다.
스키마 제약은 `Data/Persistence/Models/ItemModel.swift` 주석 참고.
