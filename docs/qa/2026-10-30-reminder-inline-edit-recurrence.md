---
참조: [cue/Presentation/Features/Reminder/ReminderView.swift, cue/Presentation/Features/Reminder/ReminderViewModel.swift, cue/Domain/UseCases/UpdateReminderUseCase.swift, cue/Data/Repositories/EventKitRemindersRepository.swift, cue/Data/Persistence/Mappers/ReminderMapper.swift]
---

# QA — 할일 인라인 편집 시 반복 소실 (2026-10-30)

- 범위: 할일에서 커스텀 반복을 만든 뒤, 목록에서 인라인으로 제목을 바꾸면 반복이 사라지는 버그 재현 → 수정 → 재검증
- 빌드(재현): d7e3049 (1.2.1) Debug 시뮬레이터 빌드
- 빌드(재검증): e80b1ec Debug 시뮬레이터 빌드 (`updateText` 심볼 포함 확인)
- 환경: iPhone 17 Pro 시뮬레이터 (iOS 26.5) / 언어 ko / 라이트 · 기본 글자 크기

## 요약

수정 전 FAIL 2(R-02·R-05) → 수정 후 전 항목 PASS 7 — 인라인 편집이 반복을 지우던 문제(커스텀·프리셋 모두) 해결 확인.

| ID | 결과 | 수정 |
|---|---|---|
| R-02 | FAIL → 수정 (e80b1ec) → 재검증 PASS | 인라인 편집이 recurrence 누락 → nil(삭제)로 저장 |
| R-05 | FAIL → 수정 (e80b1ec) → 재검증 PASS | 같은 원인 (프리셋 "매일") |

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
- 재검증: PASS — 커스텀 3일마다 지정 → 인라인으로 "격주 운동 재검증" → ✓ 직후 `check --label 3일마다` PASS
  (assets/…/r02-pass-immediate.png)

### R-03 인라인 편집 중 다른 행 탭(백그라운드 커밋) 후 반복 유지 — PASS (수정 후)
- 조작: 반복 할일 제목을 "격주 운동 R03b"로 수정 중 다른 행 "다른 할일" 텍스트를 좌표 탭(218,341)
- 근거: 편집이 "다른 할일"로 넘어가고, 첫 행은 "격주 운동 R03b · ↻ 3일마다" 유지. 재시작 후에도 유지.
- 참고: 다른 행을 **요소 탭**(`tap --contains … --type TextView`)으로 누르면 그 행이 완료 처리됨(2/2).
  좌표 탭(손가락과 같은 방식)에선 발생하지 않아 XCUITest 요소 활성화 아티팩트로 추정 — 아래 부수 발견 참고.

### R-04 앱 재시작 후에도 반복 유지(EventKit 영속) — PASS (수정 후)
- 근거: R-02 직후 앱 재시작 → "격주 운동 재검증 · ↻ 3일마다" (assets/…/r04-pass-after-restart.png)

### R-05 프리셋 반복(매일)도 인라인 편집 후 유지 — FAIL
- 조작: 세부사항 시트로 "매일" 지정(↻ 매일 표시 확인) → 인라인으로 "매일 운동"으로 제목 변경 → ✓
- 실제: ↻ 매일 사라짐 — 커스텀 한정이 아님
- 재현: 1/1회 · 원인·수정: R-02와 동일
- 재검증: PASS — "매일" 지정 → 인라인으로 "매일 운동 재검증" → ✓ 후 ↻ 매일 유지

### R-06 회귀 — 세부사항 시트에서 제목 변경·저장 시 반복 유지 — PASS
- 근거: 수정 전 — 시트에서 3일마다/매일 지정 → 저장 → 재시작 후 ↻ 유지.
  수정 후 — 시트에서 제목을 "시트 제목 변경"으로 바꿔 저장 → ↻ 매일 유지

### R-07 회귀 — 세부사항 시트에서 반복 "안 함"으로 바꾸면 반복 제거 — PASS (수정 후)
- 근거: 시트에서 반복 "안 함" → 저장 → `check --type Image --label "한 번 반복" --gone` PASS, 재시작 후에도 PASS

## 부수 발견 (범위 밖)

- **크래시 — `EventMapper.swift:14`**: 캘린더 접근이 거부된 상태(`EKCADErrorDomain 1013 접근 거부됨`)에서
  `event.eventIdentifier`(IUO)가 nil → `Fatal error: Unexpectedly found nil`. 시뮬레이터에서 앱 실행 중
  `simctl privacy grant calendar`를 건 직후 첫 인라인 커밋 때 발생. 실사용에선 권한이 바뀌면 iOS가 앱을
  재시작하는 게 보통이라 빈도는 낮을 것으로 보이나, IUO 강제 언래핑은 방어가 필요하다.
- **종일 마감 표시**: 시간을 끈 할일인데 행 메타가 "오늘 오전 12:00"으로 보임 — 의도 확인 필요.
- **요소 탭 시 행 완료**: 인라인 편집 중 다른 행의 제목 TextView를 XCUITest 요소 탭으로 누르면 그 행이 완료됨(2/2).
  좌표 탭에선 정상(편집 전환). 접근성 활성화 경로(VoiceOver 이중 탭 등)에서 같은 일이 생기는지 실기기 확인 권장.
- **접근성 라벨**: 반복 아이콘 `Image id=repeat`의 라벨이 "한 번 반복"(SF Symbol 자동 라벨)으로 읽힘.

## 2차 재검증 (2026-10-31) — 로직 재점검 + 실기동 재확인

- 빌드: e80b1ec Debug(설치 앱에 `updateText` 심볼 확인) · 같은 시뮬레이터 · 1차와 다른 더 복잡한 규칙 사용
- 로직 재점검: `update` 호출부는 VM 내부 `updateText`와 시트 `saveEdit`뿐(기본값 제거로 누락 시 컴파일 에러).
  `updateText`는 호출 시점의 `allReminders` 최신값을 실어 보내 뷰 스냅샷보다 낡은 값 덮어쓰기 위험이 적다.
  항목이 목록에 없으면 조용히 무시 — 외부 삭제 등으로 어차피 저장 불가한 경우라 문제 없음.

| ID | 결과 | 근거 |
|---|---|---|
| Q-01 커스텀 "2주마다 월·수" → 인라인 제목 변경 | PASS | `check --label 2주마다` PASS (assets/…/q01-inline-title.png) |
| Q-02 인라인 제목 재변경 ×2 | PASS | ↻ 2주마다 유지, 마감일 11/11 그대로(낡은 날짜 역기록 없음) |
| Q-03 재시작 후 규칙 세부 보존 | PASS | 시트 "반복: 2주마다 월요일 및 수요일" — 요일까지 유지 (q03-after-restart.png) |
| Q-04 시트에서 메모만 변경·저장 | PASS | 행에 "시트 메모" + ↻ 2주마다 |
| Q-05 편집 중 다른 행 좌표 탭(백그라운드 커밋) | PASS | 첫 행 제목·메모·마감·반복 모두 유지, 재시작 후도 유지 (q05-background-commit.png) |
| Q-06 시트 반복 "안 함" | PASS | 저장 직후·재시작 후 ↻ 없음 |
| Q-07 마감·반복 없는 항목 인라인 제목 변경 | PASS | 제목만 바뀌고 마감·반복 생기지 않음 |
| (부수) 편집 중 완료 → 반복 전진 | PASS | flush(`updateText`)→toggle 순서로 저장 후 10/30→11/9(월)→11/11(수) 정확히 전진, 반복 유지 |
| 인라인 **메모만** 변경 | BLOCKED | 아래 "메모 칸 포커스" 때문에 도구로 메모 칸 진입 불가. 제목과 같은 `updateText` 경로라 단위 테스트로 커버 |

### 2차 부수 발견

- **요소 탭 시 행 완료 (재확인 4/4)**: 편집 중 같은 행 메모 TextView를 XCUITest 요소 탭/`setValue`해도 그 행이 완료됨.
  좌표 탭에선 0/3. 도구 아티팩트로 보이나 VoiceOver 활성화 경로는 실기기 확인 권장(1차와 동일).
- **인라인 편집 중 메모 칸 탭으로 포커스 이동 안 됨 (의심, 좌표 탭 3/3)**: 제목 편집 중 "메모 추가"를 탭해도 커서가
  제목에 남는다. 새 입력 행 메모엔 같은 증상("List 안에서 네이티브 탭이 first responder를 못 잡음") 우회용
  overlay 탭(`focusNewMemo`)이 있는데 편집 행 메모엔 없다. 시뮬레이터 탭 특성일 수 있어 실기기 손가락 확인 필요.
  이번 변경과 무관(포커스 코드 미변경).
