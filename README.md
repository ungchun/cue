# cue

SwiftUI 기반 iOS 앱. 클린 아키텍처 3계층, 로컬 + iCloud 저장 (외부 서버 없음).

## 환경

- Xcode 26.5 / Swift 5 모드 / iOS 26.5
- Bundle ID: `azhy.cue`

## 구조

```
cue/                저장소 루트
├── ARCHITECTURE.md  아키텍처 상세 — 계층·의존성 규칙·"어디에 무엇을"
├── AGENTS.md        AI 에이전트 / 기여자 안내
├── cue.xcodeproj
└── cue/             앱 소스 (App · Domain · Data · Presentation · Core)
```

자세한 계층 설명은 [`ARCHITECTURE.md`](ARCHITECTURE.md) 참고.

## 시작하기

1. `cue.xcodeproj`를 Xcode에서 연다.
2. `cmd+R`로 시뮬레이터 실행 — 예시 화면(`ItemList`)이 동작한다.

> 현재 `Item`/`ItemList`는 **구조 예시(placeholder)**다.
> 앱 컨셉이 정해지면 실제 도메인으로 교체한다.

## iCloud 동기화 켜기

Xcode → 타깃 → **Signing & Capabilities → + Capability → iCloud → CloudKit** 체크.
코드 변경 불필요 (`cloudKitDatabase = .automatic`).

## 상태

- [x] 프로젝트 + git 세팅
- [x] 클린 아키텍처 스켈레톤 + 예시 수직 슬라이스
- [ ] 앱 컨셉 확정 → 실제 도메인 구현
- [ ] iCloud 역량 활성화
