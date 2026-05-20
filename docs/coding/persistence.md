---
참조: [ARCHITECTURE.md]
---

# 저장 — SwiftData + iCloud

외부 서버 없음. 로컬 저장 + iCloud(CloudKit) 동기화.

## 계층 규칙

- `@Model` 클래스는 `Data/Persistence/Models/`에 둔다.
- **`@Model`은 Data 계층 밖으로 노출 금지.** 항상 `...Mapper`로 도메인 엔티티(struct)로
  변환해 반환한다. Domain은 SwiftData를 모른다.
- 새 `@Model` 추가 → `ModelContainerFactory.schema` 배열에 등록.

## CloudKit 동기화 제약 🔴

위반하면 동기화가 **조용히 비활성화**된다. `@Model` 설계 시 필수:

- `@Attribute(.unique)` **금지** — 유니크는 UseCase에서 보장한다.
- 모든 속성은 **옵셔널이거나 기본값**을 가져야 한다.
- 모든 관계는 **옵셔널 + 역관계(inverse)** 필수. `.deny` 삭제 규칙·정렬 관계 금지.
- 출시 후 스키마는 **"추가만 가능"** — 이름 변경·삭제·타입 변경 불가 (= 데이터 손실).
  v1 스키마는 보수적으로 설계하고, 이후엔 속성·엔티티 추가만 한다.

## iCloud 켜기

`ModelConfiguration`의 `cloudKitDatabase`가 `.automatic`이라,
Xcode → 타깃 → **Signing & Capabilities → iCloud → CloudKit** 역량만 추가하면
코드 변경 없이 동기화가 켜진다. 역량이 없으면 로컬 전용으로 동작한다.

## 테스트

테스트는 `ModelContainerFactory.make(inMemory: true)` 또는 `InMemoryItemRepository`를
쓴다. 실제 디스크·iCloud를 건드리지 않는다.
