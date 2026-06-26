//
//  ActivityKitLiveActivityService.swift
//  cue / Data
//

// `@preconcurrency`로 import — Apple이 아직 `Activity<…>`에 Sendable 어노테이션을 붙이지
// 않아서, actor 안에서 `await activity.update(...)` / `await existing.end(...)`을 호출하면
// Swift 6 strict mode가 "Non-Sendable instance가 await 경계로 send됨"으로 잡는다.
// ActivityKit은 시스템 측에서 thread-safe라는 게 WWDC 가이드의 묵시적 전제 — `@preconcurrency`
// 로 그 신뢰를 명시적으로 표현. Apple이 향후 Sendable을 붙이면 이 어트리뷰트 제거.
@preconcurrency import ActivityKit
import Foundation

/// 메인 앱 측 라이브 액티비티 라이프사이클 구현.
///
/// **actor 격리** — ActivityKit `Activity<Attrs>`가 Non-Sendable 타입이라 `@MainActor class`
/// stored property로 보관 시 Swift 6 strict mode가 protocol Sendable conformance와의 격리
/// wrapper에서 비-격리 컨텍스트 위반을 잡는다. `actor`로 두면 모든 멤버가 자체 isolation을
/// 갖고 Non-Sendable property를 안전하게 보관할 수 있으며, protocol `Sendable` 요구도 actor가
/// 자동 만족한다.
///
/// 각 kind당 동시 1개 인스턴스만 보관 — 같은 kind로 start가 들어오면 기존을 `.immediate`로
/// 종료하고 새로 시작한다(토글성 트리거에서 호출처 부담 제거).
///
/// **타이머 매초 update 금지** — Focus는 `phaseEndDate`·`pauseTime`만 ContentState에 두고
/// 위젯에서 `Text(timerInterval:pauseTime:)` / `ProgressView(timerInterval:)`이 시스템
/// 위임으로 자동 갱신한다. 앱은 transition(pause/resume/skip/phase 전환)에서만 update.
///
/// **dismissalPolicy 정책**:
/// - Focus 종료: 결과를 60초간 보여주고 dismiss (사용자 만족감)
/// - Reminder/Schedule 종료: `.immediate` (정보성, 즉시 정리)
///
/// **권한** — `isEnabled` false면 `start*`는 silently skip한다(throw 대신 no-op). 호출처가
/// `service.isEnabled`를 먼저 확인해 alert·설정 딥링크로 분기하는 게 정석.
///
/// **sync** — `Activity<Attrs>.activities` 정적 컬렉션에서 살아있는 인스턴스를 재포착.
/// 앱 강제 종료 후 복귀 시 시스템은 Activity를 보존하나 핸들은 잃었으므로 동기화 필요.
actor ActivityKitLiveActivityService: LiveActivityService {

    private var reminderActivity: Activity<ReminderLiveActivityAttributes>?
    private var scheduleActivity: Activity<ScheduleLiveActivityAttributes>?
    private var memoActivity: Activity<MemoLiveActivityAttributes>?

    init() {}

    /// 시스템 설정 + OS budget으로 라이브 액티비티가 활성화돼 있는지.
    /// `request` 직전마다 호출 — false면 시도 자체를 하지 않는다.
    var isEnabled: Bool {
        get async {
            ActivityAuthorizationInfo().areActivitiesEnabled
        }
    }

    // 집중(Focus) LA는 AlarmKit으로 이관됨 — 여기선 Reminder/Schedule만 다룬다.

    // MARK: - Reminder

    func startReminder(
        listTitle: String,
        items: [LiveReminderItem],
        remaining: Int,
        todayCount: Int
    ) async throws {
        guard await isEnabled else { return }

        let state = ReminderLiveActivityAttributes.ContentState(
            items: items,
            remaining: remaining,
            todayCount: todayCount
        )
        // 시간 흐름과 무관 — staleDate 미지정. 사용자 동작 시점에만 update.
        let content = ActivityContent(state: state, staleDate: nil)

        // 같은 리스트로 이미 떠 있으면 **부드럽게 update** — 재시작은 깜빡임 + 새 인스턴스 발생.
        // listTitle은 attributes(불변)라, 리스트가 바뀐 경우엔 end 후 새로 request해야 한다.
        if let existing = reminderActivity, existing.attributes.listTitle == listTitle {
            await existing.update(content)
            return
        }

        if let existing = reminderActivity {
            await existing.end(nil, dismissalPolicy: .immediate)
            reminderActivity = nil
        }

        let attributes = ReminderLiveActivityAttributes(listTitle: listTitle)
        reminderActivity = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
    }

    func endReminder() async {
        guard let activity = reminderActivity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        reminderActivity = nil
    }

    // MARK: - Schedule

    func startSchedule(days: [LiveScheduleDay], todayCount: Int) async throws {
        guard await isEnabled else { return }

        if let existing = scheduleActivity {
            await existing.end(nil, dismissalPolicy: .immediate)
            scheduleActivity = nil
        }

        let attributes = ScheduleLiveActivityAttributes(startedAt: .now)
        let state = ScheduleLiveActivityAttributes.ContentState(days: days, todayCount: todayCount)
        // staleDate = "이 시점 이후 정보는 오래됨"을 시스템에 알리는 미래 시각.
        // **과거 시각을 넣으면 request 직후 시스템이 즉시 stale로 처리해 화면에 표시 자체가
        // 안 뜬다** — 오늘 첫 이벤트가 이미 시작된 시각인 경우(오후에 토글)가 흔한 함정.
        // 따라서 `> now`인 미래 시작 시각 중 가장 가까운 것만 staleDate로 채택, 없으면 nil
        // (시간 흐름과 무관 — 사용자 동작에서만 갱신).
        let now = Date.now
        let upcomingStart = days
            .flatMap(\.events)
            .map(\.startDate)
            .filter { $0 > now }
            .min()
        let content = ActivityContent(state: state, staleDate: upcomingStart)

        scheduleActivity = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
    }

    func endSchedule() async {
        guard let activity = scheduleActivity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        scheduleActivity = nil
    }

    // MARK: - Memo

    func startMemo(text: String, colorHex: String) async throws {
        guard await isEnabled else { return }

        let state = MemoLiveActivityAttributes.ContentState(text: text, colorHex: colorHex)
        // 시간 흐름과 무관 — staleDate 미지정. 사용자가 텍스트·색을 바꿀 때만 update.
        let content = ActivityContent(state: state, staleDate: nil)

        // 이미 떠 있으면 부드럽게 update — 텍스트·색 모두 ContentState라 재시작이 필요 없다.
        if let existing = memoActivity {
            await existing.update(content)
            return
        }

        let attributes = MemoLiveActivityAttributes(startedAt: .now)
        memoActivity = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
    }

    func endMemo() async {
        guard let activity = memoActivity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        memoActivity = nil
    }

    // MARK: - Sync

    func sync() async {
        // 시스템에 살아있는 첫 번째 인스턴스를 재포착. kind당 1개 정책이라 first로 충분.
        reminderActivity = Activity<ReminderLiveActivityAttributes>.activities.first
        scheduleActivity = Activity<ScheduleLiveActivityAttributes>.activities.first
        memoActivity = Activity<MemoLiveActivityAttributes>.activities.first
    }
}
