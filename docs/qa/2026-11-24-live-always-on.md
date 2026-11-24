# 수정 기록 — 라이브 항상 표시(할일) (2026-11-24)

- 제보: "라이브 항상 표시"를 할일·오늘로 켜 두면 가끔 갱신이 안 되고, 이미 완료한 할일이 카드에 남는다.
  예전엔 괜찮다가 최근에 그런 것 같다.
- 결과: 원인 4개를 고쳤다. push 전 리뷰에서 2개를 더 찾아 같이 고쳤다. 6커밋, 테스트 커밋 1개.
- 검증:
  - 단위 테스트를 새로 썼다(`ReminderViewModelTests` 7개, `ScheduleViewModelTests` 1개).
  - 앱·테스트 타깃 컴파일(`build-for-testing`)은 통과했다. 테스트 실행은 사용자 몫이다.
- 기존 사용자: 저장 형식(설정·SwiftData·UserDefaults 키)은 바꾸지 않았다. 마이그레이션은 필요 없다.
- 참조: [Duo UI 마무리](2026-11-24-duo-ui-final.md)(같은 push), `ReminderViewModel.swift`, `EventKitRemindersRepository.swift`

## 원인과 수정

### `917df88` 앱을 열 때 완료한 할일이 카드에 다시 나타남
- 원인:
  - 첫 적재는 저장해 둔 목록(스냅샷)을 먼저 그리고, 이때 `hasLoaded`를 세운다.
  - 항상 표시 게시는 이 표시만 보고 스냅샷으로 카드를 올렸다.
  - 실제 조회가 끝난 뒤의 갱신은 건너뛰었다. 그 순간엔 카드가 아직 켜짐으로 표시되지 않아서다.
- 수정: 게시 전에 첫 최신 조회(`firstLoadTask`)가 끝나길 기다린다.

### `ebfb19e` 데이터가 바뀌면 카드가 설정 범위 대신 할일 탭 목록으로 바뀜
- 원인: 갱신이 항상 할일 탭의 현재 선택(`visibleReminders`)으로 게시했다.
- 수정:
  - 항상 표시 카드는 설정 범위(`alwaysOnScopeID`)를 기억하고, 갱신도 그 범위로 한다.
  - 라이브 버튼으로 직접 켜면 범위를 지운다. 그 카드는 할일 탭 선택을 따른다(항상 표시 카드 위에서 켜도 같다).

### `dd9fd8f` 앱 밖에서 완료한 할일이 포그라운드 복귀 뒤에도 남음
- 원인:
  - 카드가 이미 켜져 있으면 복귀 때 아무것도 하지 않았다.
  - 라이브 체크 버튼이나 미리 알림 앱으로 쓴 값은 변경 알림이 빠지면 `EKEventStore` 캐시에 남는다.
- 수정: 복귀 때 캐시를 버리고(`DiscardRemindersCacheUseCase` → `store.reset()`) 다시 읽어 카드를 갱신한다.

### `83adad9` 일정 탭 할일 시트에서 완료한 할일이 카드에 남음
- 원인: 할일 VM은 변경 알림만 믿어서, 알림이 빠지면 모른다.
- 수정:
  - `ScheduleViewModel(afterReminderWrite:)`가 쓰기 뒤 `ReminderViewModel.reloadAfterExternalWrite()`를 부른다.
  - 이 호출은 자기 쓰기 에코 억제 창(2초)을 무시한다.

### `7488e29` (리뷰) 캐시 비우기가 진행 중인 조회와 겹칠 수 있음
- 원인: `fetchReminders`가 EventKit 완료 콜백을 기다리는 동안 actor가 재진입된다. 그 사이 `reset()`이 끼면 조회 도중 store가 비워진다.
- 수정: 이미 있던 `SerialGate`로 조회와 비우기를 차례로 돌린다. EventKit I/O 글루라 RED는 면제다.

### `7476dc0` (리뷰) 오늘 카드가 저장된 오늘 정렬을 잃음
- 원인: 오늘 정렬 설정은 할일 탭이 오늘을 볼 때만 불러온다. 탭이 "전체"면 카드가 기본 정렬로 떴다.
  카드는 6개까지만 보여서, 위 6개가 바뀔 수 있었다.
- 수정: 게시 전에 설정 범위의 정렬 설정을 불러온다(이미 있으면 건너뜀).

## 바뀐 뒤 동작

| 카드 | 동작 |
|---|---|
| 항상 표시 (Premium) | 설정 범위·정렬을 유지한다. 앱을 열 때와 돌아올 때 최신 값으로 갱신한다 |
| 라이브 버튼으로 직접 켠 카드 | 할일 탭 선택을 따른다(전과 같음). 완료·복귀로는 항상 표시 범위로 돌아가지 않는다 |
| 항상 표시 범위로 다시 바뀌는 때 | 앱을 완전히 종료한 뒤 다시 켤 때, 설정에서 항상 표시 값을 바꿀 때(전과 같음) |

## 테스트 (새로 씀)

| 테스트 | 고정하는 것 |
|---|---|
| `alwaysOnPublishesFreshFetchNotCachedSnapshot` | 917df88 — 스냅샷이 아니라 최신 조회로 게시 |
| `alwaysOnCardKeepsConfiguredScopeWhenDataChanges` | ebfb19e — 데이터가 바뀌어도 설정 범위 유지 |
| `manualToggleOverAlwaysOnCardFollowsTabSelection` | ebfb19e — 직접 켠 카드는 탭 선택을 따름 |
| `alwaysOnWhileActiveRefetchesAndRepublishes` | dd9fd8f — 캐시를 버린 **뒤에** 다시 읽음 |
| `reloadAfterExternalWriteRefreshesActiveLiveActivity` | 83adad9 — 일정 탭 쓰기 뒤 카드 갱신 |
| `reloadAfterExternalWriteIgnoresSelfWriteSuppressWindow` | 83adad9 — 억제 창 안에서도 갱신 |
| `reminderSheetWriteNotifiesAfterReminderWrite` (`ScheduleViewModelTests`) | 83adad9 — 쓰기 성공 시에만 1회 알림 |
| `alwaysOnTodayCardUsesSavedTodaySortWhileTabShowsAnotherScope` | 7476dc0 — 저장된 오늘 정렬로 게시 |

## 남은 것 (고치지 않음)

- 무료 사용자가 직접 켠 카드(예전부터 있던 동작):
  - 앱이 백그라운드일 때 라이브 체크 버튼으로 완료하면, 복귀 뒤 첫 앱 안 쓰기가 낡은 store를 읽는다.
  - 그러면 완료한 할일이 카드에 되살아날 수 있다.
  - 복귀 시 캐시 비우기(`startAlwaysOnLiveActivity`)는 Premium 항상 표시 경로에서만 돈다.
- 기존 테스트의 약한 곳 11개(이번 변경과 무관, push 전 전체 테스트 점검에서 발견):
  - 타이밍에 따라 실패할 수 있음:
    - `FocusViewModelTests.swift:376-378`: `Task.yield()` 2번 → `flushPersistence()`로 바꿀 것
  - 실제 App Group에 씀:
    - `FetchStartTabIDUseCaseTests.swift:17, 48`: `group:` 주입이 빠졌다
  - 항상 통과함:
    - `ReviewPromptPolicyTests.swift:38-42`: 운영 코드를 부르지 않는다
    - `MonthWidgetMetricsTests.swift:113-127`: 산술 항등식만 검증한다
    - `ReminderRecurrenceMappingTests.swift:208, 230`: `x == x`
    - `LiveActivityUseCaseTests.swift:181, 201`: 빈 배열도 통과한다
    - `DayTimelineLayoutTests.swift:270-282`: 설정이 이름과 맞지 않는다
    - `cueTests.swift:13`: 빈 템플릿
  - 주석·검증 어긋남:
    - `WeekEventDotsBuilderTests.swift:84-89`: 낡은 주석
    - `ScheduleMonthViewModelTests.swift:86-91`: `waitUntil` 시간 초과가 조용히 넘어간다
    - `DayTimelineLayoutTests.swift:184-196`: gap 빼기를 검증하지 않고, 주석이 가리키는 테스트도 없다
