---
참조: [ARCHITECTURE.md]
---

# 코딩 컨벤션

## 파일·타입

- **1 파일 = 1 타입.** 파일명 = 타입명.
- 역할 접미사로 계층·책임을 드러낸다:
  `...UseCase` / `...Repository`(프로토콜) / `SwiftData...Repository`(구현) /
  `...Model`(@Model) / `...ViewModel` / `...View` / `...Mapper` / `...Route`.
- 파일 상단에 `// 파일명 / 계층` 주석.

## import 규칙 (계층별)

[ARCHITECTURE.md](../../ARCHITECTURE.md)의 의존성 규칙을 import로 강제한다:

| 계층 | 허용 | 금지 |
|---|---|---|
| `Domain/` | `Foundation` | `SwiftUI`, `SwiftData` |
| `Data/` | `Foundation`, `SwiftData` | `SwiftUI` |
| `Presentation/` | `SwiftUI` | `SwiftData`, `Data`의 구체 타입 |
| `App/` | 전부 (조립 담당) | — |

## 네이밍

- 타입 `UpperCamelCase`, 변수·함수 `lowerCamelCase`.
- 이름은 역할을 정확히 드러낸다. 모호한 `data`, `info`, `manager`, `helper` 지양.
- 불리언은 `is` / `has` / `should` 접두.

## 에러 처리

- 도메인 오류는 `DomainError`로 표현한다 (`Domain/Errors/`).
- **Data 계층은 하위 오류(SwiftData 등)를 `DomainError`로 변환**해 던진다 —
  Domain/Presentation이 SwiftData 오류 타입을 직접 보지 않게.
- `try?`로 오류를 조용히 삼키지 않는다. 처리하거나 전파한다.
- 사용자에게 보일 메시지는 `LocalizedError.errorDescription`으로.

## 기타

- 매직 넘버·문자열은 상수로. UI 간격은 `Presentation/DesignSystem/Spacing`.
- `print` 대신 `AppLogger` (`Core/AppLogger.swift`).
- 강제 언래핑(`!`) 지양 — 테스트·명백한 불변식 외.
