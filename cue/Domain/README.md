# Domain 계층

앱의 **핵심 규칙**. 아무것도 의존하지 않는다 (`Foundation`만 허용).

## 금지 사항
- `import SwiftUI` ❌
- `import SwiftData` ❌
- 그 외 외부 프레임워크 ❌

## 폴더
| 폴더 | 담는 것 |
|---|---|
| `Entities/` | 순수 Swift 모델 (struct). 예: `Item` |
| `Repositories/` | 저장소 **프로토콜**만. 구현은 Data 계층 |
| `UseCases/` | 비즈니스 동작 1개 = 타입 1개. 상태 없음 |
| `Errors/` | 도메인 오류 타입 |

## 규칙
- Repository는 프로토콜로만 정의하고, Data 계층이 구현한다 (의존성 역전).
- UseCase는 `callAsFunction`으로 호출 가능하게 만든다.
- 엔티티는 `Sendable` 값 타입(struct)으로 둔다.
