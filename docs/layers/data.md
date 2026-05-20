---
참조: [ARCHITECTURE.md, docs/coding/persistence.md]
---

# Data 계층

위치: `cue/Data/`. `Domain`이 정의한 Repository 프로토콜을 **구현**한다. `Domain`에만 의존한다.

## 폴더
| 폴더 | 담는 것 |
|---|---|
| `Persistence/Models/` | SwiftData `@Model` 클래스 (`...Model`) |
| `Persistence/Mappers/` | `@Model` ↔ 도메인 엔티티 변환 (`...Mapper`) |
| `Persistence/` | `ModelContainerFactory` (컨테이너 생성) |
| `Repositories/` | Repository 프로토콜 구현 (`SwiftData...Repository`, `InMemory...Repository`) |

## 규칙
- `@Model` 클래스는 이 계층 밖으로 노출하지 않는다. 항상 Mapper로 도메인 엔티티로 변환해 반환한다.
- SwiftData/CloudKit 오류는 `DomainError`로 변환해 던진다.
- 새 `@Model`을 추가하면 `ModelContainerFactory.schema`에 등록한다.

CloudKit 동기화·스키마 제약은 [docs/coding/persistence.md](../coding/persistence.md) 참고.
