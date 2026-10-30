---
참조: [cue/Presentation/Features/Reminder/ReminderView.swift, cue/Presentation/Features/Reminder/ReminderViewModel.swift, cue/Domain/UseCases/UpdateReminderUseCase.swift, cue/Data/Repositories/EventKitRemindersRepository.swift, cue/Data/Persistence/Mappers/ReminderMapper.swift]
---

# QA — 할일 인라인 편집 시 반복 소실 (2026-10-30)

- 범위: 할일에서 커스텀 반복을 만든 뒤, 목록에서 인라인으로 제목을 바꾸면 반복이 사라지는 버그 재현 → 수정 → 재검증
- 빌드(재현): d7e3049 (1.2.1) Debug 시뮬레이터 빌드
- 환경: iPhone 17 Pro 시뮬레이터 (iOS 26.5) / 언어 ko / 라이트 · 기본 글자 크기

## 요약

PASS 1 · FAIL 2 · 대기 4 — 인라인 편집이 반복을 지운다(커스텀·프리셋 모두). 수정 완료, 재검증은 사용자 빌드 대기.

| ID | 결과 | 수정 |
|---|---|---|
| R-02 | FAIL → 수정 → 재검증 대기 | 인라인 편집이 recurrence 누락 → nil(삭제)로 저장 |
| R-05 | FAIL → 수정 → 재검증 대기 | 같은 원인 (프리셋 "매일") |

## 체크리스트

### R-01 커스텀 반복 할일 생성 — PASS
- 조작: 새 행에 "격주 운동" 입력 → ⓘ → 날짜 켬 → 반복 → 사용자화 → 3일마다 → 저장
- 근거: 행 메타 `Image “한 번 반복” id=repeat` + `StaticText “3일마다”`. 앱 재시작 후에도 유지.

### R-02 인라인 제목 변경 후 반복 유지 — FAIL
- 전제: R-01 할일(↻ 3일마다)
- 조작: 행 제목 탭 → "격주 운동 2차"로 교체 → 상단 ✓(닫기)
- 기대: ↻ 3일마다 유지
- 실제: 커밋 직후 ↻ 표시 사라짐. 앱 재시작 후에도 없음, 세부사항 시트도 "반복: 안 함" → EventKit 규칙 자체가 삭제됨.
- 재현: 2/2회
- 근거: assets/2026-10-30-reminder-inline-edit-recurrence/r02-fail-immediate.png, r02-fail-after-restart.png
- 원인: `ReminderView`의 인라인 커밋 3곳(`flushInlineEditAwaiting`·`backgroundCommit`·`commitInlineEdit`)이
  `viewModel.update`에 `recurrence:`를 넘기지 않음 → 기본값 `nil` → `EventKitRemindersRepository.updateReminder`가
  기존 규칙과 비동치로 보고 `removeRecurrenceRule`. 인라인 편집(704435b)이 반복 기능(0f3b2c8)보다 먼저 있었고,
  반복 추가 시 매개변수 기본값 `= nil` 때문에 옛 호출부가 컴파일 에러 없이 남았다.
- 수정: ViewModel에 `updateText(reminderID:title:notes:)` 추가 — 현재 항목의 마감일·반복을 그대로 실어 저장.
  인라인 3곳은 이걸 호출. `update`의 dueDate·includesTime·recurrence 기본값 제거(빠뜨리면 컴파일 에러).
  테스트: `updateTextPreservesDueDateAndRecurrence`(저장소 값까지 확인), `updateWithNilRecurrenceClearsIt`.
- 재검증: 대기

### R-03 인라인 편집 중 다른 행 탭(백그라운드 커밋) 후 반복 유지 — 대기
- 수정 전 코드상 같은 결함(`backgroundCommit`) — 재검증 시 실기동 확인

### R-04 앱 재시작 후에도 반복 유지(EventKit 영속) — 대기

### R-05 프리셋 반복(매일)도 인라인 편집 후 유지 — FAIL
- 조작: 세부사항 시트로 "매일" 지정(↻ 매일 표시 확인) → 인라인으로 "매일 운동"으로 제목 변경 → ✓
- 실제: ↻ 매일 사라짐 — 커스텀 한정이 아님
- 재현: 1/1회 · 원인·수정: R-02와 동일
- 재검증: 대기

### R-06 회귀 — 세부사항 시트에서 반복 지정·저장 시 유지 — PASS(수정 전)
- 근거: 시트에서 3일마다/매일 지정 → 저장 → 재시작 후 ↻ 유지
- 재검증: 대기

### R-07 회귀 — 세부사항 시트에서 반복 "안 함"으로 바꾸면 반복 제거 — 대기

## 부수 발견 (범위 밖)

- **크래시 — `EventMapper.swift:14`**: 캘린더 접근이 거부된 상태(`EKCADErrorDomain 1013 접근 거부됨`)에서
  `event.eventIdentifier`(IUO)가 nil → `Fatal error: Unexpectedly found nil`. 시뮬레이터에서 앱 실행 중
  `simctl privacy grant calendar`를 건 직후 첫 인라인 커밋 때 발생. 실사용에선 권한이 바뀌면 iOS가 앱을
  재시작하는 게 보통이라 빈도는 낮을 것으로 보이나, IUO 강제 언래핑은 방어가 필요하다.
- **종일 마감 표시**: 시간을 끈 할일인데 행 메타가 "오늘 오전 12:00"으로 보임 — 의도 확인 필요.
- **접근성 라벨**: 반복 아이콘 `Image id=repeat`의 라벨이 "한 번 반복"(SF Symbol 자동 라벨)으로 읽힘.
