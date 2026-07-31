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
    /// 마지막 일정 게시의 **전체(미-cap) days** — 캘린더 함께 보기를 껐다 켤 때 refreshLayout이
    /// 게시된 (cap된) 상태가 아니라 이 원본에서 다시 계산해 이벤트 손실을 막는다.
    private var lastScheduleDays: [LiveScheduleDay] = []
    /// 마지막 할일 게시의 **전체(미-cap) items** — 일정과 같은 이유(캘린더 토글 복원).
    private var lastReminderItems: [LiveReminderItem] = []

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
        todayCount: Int,
        weekEventDots: [LiveDayEventDots],
        showsCalendarOverride: Bool?,
        isSample: Bool
    ) async throws {
        guard await isEnabled else { return }

        // 캘린더 껐다 켤 때 원본에서 복원하도록 전체 items 보관(cap 이전).
        lastReminderItems = items
        // 표시 여부는 **여기서 확정해 상태에 싣는다** — 위젯이 렌더 시점에 미러를 읽으면
        // 미러가 어긋난 순간 "설정 ON인데 캘린더 없음"이 되고 위젯 쪽에선 복구가 불가능하다.
        // 오버라이드(온보딩 목업)면 미러 대신 그 값을 따르고, 예시는 **점을 싣지 않는다** —
        // 목업 캘린더는 사용자 실데이터 없이 이번 달만 정적으로 보여준다.
        let showsCalendar = showsCalendarOverride
            ?? SharedAppGroup.defaults.bool(forKey: SharedAppGroup.Keys.reminderShowsCalendar)
        let monthDots = showsCalendar && !isSample
            ? CalendarMonthDots.dots(monthOffset: 0) : []
        var state = Self.fittedReminderState(
            items: items, remaining: remaining, todayCount: todayCount,
            weekEventDots: weekEventDots, monthEventDots: monthDots
        )
        state.showsCalendar = showsCalendar
        state.isSample = isSample
        // 시간 흐름과 무관 — staleDate 미지정. 사용자 동작 시점에만 update.
        // Dynamic Island 우선순위(relevanceScore): 집중(AlarmKit, 시스템 우선) > 메모(3) > 일정=할일(2).
        let content = ActivityContent(state: state, staleDate: nil, relevanceScore: 2)

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
        stampRingAnchor()
        reminderActivity = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
        LiveActivityIntentRecord.markStarted(.reminder)
    }

    func endReminder() async {
        // 기록은 핸들 유무와 무관하게 지운다 — 사용자가 잠금화면에서 직접 밀어 없앤 뒤라
        // 핸들이 이미 비어 있어도 "끄겠다"는 의사는 기록에 반영돼야 한다.
        LiveActivityIntentRecord.markEnded(.reminder)
        guard let activity = reminderActivity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        reminderActivity = nil
        lastReminderItems = []
    }

    // MARK: - Schedule

    func startSchedule(
        days: [LiveScheduleDay],
        todayCount: Int,
        weekEventDots: [LiveDayEventDots],
        showsCalendarOverride: Bool?,
        isSample: Bool
    ) async throws {
        guard await isEnabled else { return }

        if let existing = scheduleActivity {
            await existing.end(nil, dismissalPolicy: .immediate)
            scheduleActivity = nil
        }

        let attributes = ScheduleLiveActivityAttributes(startedAt: .now)

        // 캘린더 껐다 켤 때 원본에서 다시 계산하도록 전체 days를 보관한다(cap 이전 값).
        lastScheduleDays = days
        // 표시 여부를 여기서 확정해 상태에 싣는다(할일 쪽 주석 참고). 이벤트는 예산에 맞는
        // 만큼 최대로. 예시(목업)는 점을 싣지 않는다 — 이번 달만 정적으로 보여준다.
        let showsCalendar = showsCalendarOverride
            ?? SharedAppGroup.defaults.bool(forKey: SharedAppGroup.Keys.scheduleShowsCalendar)
        let monthDots = showsCalendar && !isSample
            ? CalendarMonthDots.dots(monthOffset: 0) : []
        var state = Self.fittedScheduleState(days: days, todayCount: todayCount, weekEventDots: weekEventDots, monthEventDots: monthDots)
        state.showsCalendar = showsCalendar
        state.isSample = isSample
        // staleDate = "이 시점 이후 정보는 오래됨"을 시스템에 알리는 미래 시각.
        // **과거 시각을 넣으면 request 직후 시스템이 즉시 stale로 처리해 화면에 표시 자체가
        // 안 뜬다** — 오늘 첫 이벤트가 이미 시작된 시각인 경우(오후에 토글)가 흔한 함정.
        // 따라서 `> now`인 미래 시작 시각 중 가장 가까운 것만 staleDate로 채택, 없으면 nil.
        let now = Date.now
        let upcomingStart = state.days
            .flatMap(\.events)
            .map(\.startDate)
            .filter { $0 > now }
            .min()
        // 일정은 할일과 동일 우선순위(2) — Dynamic Island 표시가 같아 함께 둔다.
        let content = ActivityContent(state: state, staleDate: upcomingStart, relevanceScore: 2)

        stampRingAnchor()
        scheduleActivity = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
        LiveActivityIntentRecord.markStarted(.schedule)
    }

    func endSchedule() async {
        // 기록은 핸들 유무와 무관하게 지운다(endReminder 주석 참고).
        LiveActivityIntentRecord.markEnded(.schedule)
        guard let activity = scheduleActivity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        scheduleActivity = nil
        lastScheduleDays = []
    }

    // MARK: - 온보딩 예시 정리

    /// 예시 마커(`isSample`)가 박힌 일정·할일 활동만 종료한다.
    /// 보관 중인 핸들이 아니라 시스템 컬렉션을 스캔 — 앱 재시작으로 핸들이 유실된
    /// 지난 실행의 예시도 정리된다. 실사용 게시는 마커가 항상 nil이라 안 걸린다.
    func endSamples() async {
        for activity in Activity<ScheduleLiveActivityAttributes>.activities
        where activity.content.state.isSample {
            await activity.end(nil, dismissalPolicy: .immediate)
            // 예시도 `startSchedule`을 거치므로 기록이 남는다 — 사용자가 고른 적 없는
            // 것을 자동화가 8시간마다 되살리지 않도록 여기서 지운다.
            LiveActivityIntentRecord.markEnded(.schedule)
            if scheduleActivity?.id == activity.id {
                scheduleActivity = nil
                lastScheduleDays = []
            }
        }
        for activity in Activity<ReminderLiveActivityAttributes>.activities
        where activity.content.state.isSample {
            await activity.end(nil, dismissalPolicy: .immediate)
            // 예시 기록 정리(위 주석 참고).
            LiveActivityIntentRecord.markEnded(.reminder)
            if reminderActivity?.id == activity.id {
                reminderActivity = nil
                lastReminderItems = []
            }
        }
    }

    // MARK: - Memo

    func startMemo(text: String, colorHex: String, textColorHex: String) async throws {
        guard await isEnabled else { return }

        // 메모도 표시 여부를 게시 시점에 확정해 싣는다(할일·일정과 동일).
        let showsCalendar = SharedAppGroup.defaults.bool(forKey: SharedAppGroup.Keys.memoShowsCalendar)
        var state = MemoLiveActivityAttributes.ContentState(text: text, colorHex: colorHex, textColorHex: textColorHex)
        state.showsCalendar = showsCalendar
        state.monthEventDots = showsCalendar ? CalendarMonthDots.dots(monthOffset: 0) : []
        // 시간 흐름과 무관 — staleDate 미지정. 사용자가 텍스트·색을 바꿀 때만 update.
        // 메모는 일정·할일보다 높은 우선순위(3) — 집중(AlarmKit) 다음으로 앞에 뜬다.
        let content = ActivityContent(state: state, staleDate: nil, relevanceScore: 3)

        // 이미 떠 있으면 부드럽게 update — 텍스트·색 모두 ContentState라 재시작이 필요 없다.
        if let existing = memoActivity {
            await existing.update(content)
            // 갱신 경로에서도 기록을 다시 세운다 — 앱을 지웠다 깔거나 App Group이 비었을 때
            // 라이브는 떠 있는데 기록만 없는 상태가 되면 자동화가 그 라이브를 포기한다.
            LiveActivityIntentRecord.markStarted(.memo)
            return
        }

        let attributes = MemoLiveActivityAttributes(startedAt: .now)
        stampRingAnchor()
        memoActivity = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
        LiveActivityIntentRecord.markStarted(.memo)
    }

    func endMemo() async {
        // 기록은 핸들 유무와 무관하게 지운다(endReminder 주석 참고).
        LiveActivityIntentRecord.markEnded(.memo)
        guard let activity = memoActivity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        memoActivity = nil
    }

    // MARK: - Ring anchor

    /// LA 게시 시각을 App Group에 기록 — 위젯의 `activity8h` 진행 링이 8시간 기준점으로 읽는다.
    /// 갱신(update)이 아닌 새 게시(`Activity.request`) 직전에만 호출해 기준점을 재설정한다.
    private func stampRingAnchor() {
        SharedAppGroup.defaults.set(Date.now.timeIntervalSince1970, forKey: SharedAppGroup.Keys.ringAnchor)
    }

    /// ContentState 인코딩 크기 예산 — ActivityKit ~4KB 한도에 여유(그 자체 인코딩 오버헤드 대비).
    /// 이 값 이하가 되도록 아이템/이벤트를 적응적으로 줄인다.
    private static let contentStateByteBudget = 3500

    /// 후보 개수를 큰 것부터 시도한다 — 들어가면 그대로, 안 들어가면 한 단계 줄인다(네 아이디어: 20→15→10→6).
    private static let itemCapLadder = [20, 15, 10, 6, 3]

    /// 인코딩 크기가 예산 안인지 — 실제 게시(request/update) 전에 미리 재서 실패를 예방한다.
    private static func fits<T: Encodable>(_ state: T) -> Bool {
        ((try? JSONEncoder().encode(state))?.count ?? .max) <= contentStateByteBudget
    }

    /// 예산에 맞는 가장 큰 할일 ContentState — 전체부터 시도해 안 들어가면 사다리대로 줄인다.
    private static func fittedReminderState(
        items: [LiveReminderItem], remaining: Int, todayCount: Int,
        weekEventDots: [LiveDayEventDots], monthEventDots: [LiveMonthDot]
    ) -> ReminderLiveActivityAttributes.ContentState {
        func make(_ n: Int) -> ReminderLiveActivityAttributes.ContentState {
            var s = ReminderLiveActivityAttributes.ContentState(
                items: Array(items.prefix(n)), remaining: remaining, todayCount: todayCount, weekEventDots: weekEventDots
            )
            s.monthEventDots = monthEventDots
            return s
        }
        let candidates = [items.count] + itemCapLadder.filter { $0 < items.count }
        for n in candidates where n > 0 {
            let s = make(n)
            if fits(s) { return s }
        }
        return make(Swift.min(3, items.count))   // 최소치라도 게시(예산을 못 맞춰도 최선).
    }

    /// 예산에 맞는 가장 큰 일정 ContentState — 이벤트 총량을 전체부터 사다리대로 줄인다.
    private static func fittedScheduleState(
        days: [LiveScheduleDay], todayCount: Int,
        weekEventDots: [LiveDayEventDots], monthEventDots: [LiveMonthDot]
    ) -> ScheduleLiveActivityAttributes.ContentState {
        func make(_ n: Int) -> ScheduleLiveActivityAttributes.ContentState {
            var s = ScheduleLiveActivityAttributes.ContentState(
                days: cappingEvents(days, max: n), todayCount: todayCount, weekEventDots: weekEventDots
            )
            s.monthEventDots = monthEventDots
            return s
        }
        let total = days.reduce(0) { $0 + $1.events.count }
        let candidates = [total] + itemCapLadder.filter { $0 < total }
        for n in candidates where n > 0 {
            let s = make(n)
            if fits(s) { return s }
        }
        return make(Swift.min(3, total))
    }

    /// 날짜 묶음의 이벤트 총량을 앞에서부터 `max`개로 자른다(초과 날짜/이벤트 제거).
    private static func cappingEvents(_ days: [LiveScheduleDay], max: Int) -> [LiveScheduleDay] {
        var remaining = max
        var result: [LiveScheduleDay] = []
        for day in days {
            if remaining <= 0 { break }
            let kept = Array(day.events.prefix(remaining))
            guard !kept.isEmpty else { continue }
            remaining -= kept.count
            result.append(LiveScheduleDay(id: day.id, label: day.label, events: kept))
        }
        return result
    }

    // MARK: - Sync

    func sync() async {
        // 시스템에 살아있는 첫 번째 인스턴스를 재포착. kind당 1개 정책이라 first로 충분.
        reminderActivity = Activity<ReminderLiveActivityAttributes>.liveActivity
        scheduleActivity = Activity<ScheduleLiveActivityAttributes>.liveActivity
        memoActivity = Activity<MemoLiveActivityAttributes>.liveActivity
    }

    // MARK: - Refresh

    func refreshLayout() async {
        // 캘린더 함께 표시 설정의 대상인 메모·일정·할일을 재게시한다. 핸들이 유실됐을 수 있어
        // (설정 화면이 sync보다 먼저 쓰이는 경우) 재포착 후 갱신. 캘린더 점도 표시 월 기준 재계산.
        reminderActivity = Activity<ReminderLiveActivityAttributes>.liveActivity
        memoActivity = Activity<MemoLiveActivityAttributes>.liveActivity
        scheduleActivity = Activity<ScheduleLiveActivityAttributes>.liveActivity

        if let reminder = reminderActivity {
            let prev = reminder.content.state
            // 예시(목업)는 게시 시점 결정을 유지하고 점은 계속 비워둔다(정적 목업).
            // 실사용은 최신 설정으로 다시 결정한다 — 설정 토글 직후 재게시가 이 경로다.
            let showsCalendar = prev.isSample
                ? (prev.showsCalendar ?? false)
                : SharedAppGroup.defaults.bool(forKey: SharedAppGroup.Keys.reminderShowsCalendar)
            // 보관본을 그대로 쓰면 LA에서 체크해 지운 항목이 되살아난다 — 체크는 서비스를
            // 거치지 않고 Activity를 직접 갱신하므로 보관본이 그 삭제를 모른다.
            // 화면과 대조해 지운 것은 빼고 cap으로 잘린 것만 되살린다.
            let source = LiveActivityRefreshSource.reminderItems(
                backup: lastReminderItems, onScreen: prev.items
            )
            let monthDots = showsCalendar && !prev.isSample
                ? CalendarMonthDots.dots(monthOffset: prev.calendarMonthOffset) : []
            var state = Self.fittedReminderState(
                items: source, remaining: prev.remaining, todayCount: prev.todayCount,
                weekEventDots: prev.weekEventDots, monthEventDots: monthDots
            )
            state.calendarMonthOffset = prev.calendarMonthOffset
            state.showsCalendar = showsCalendar
            state.isSample = prev.isSample
            await reminder.update(ActivityContent(state: state, staleDate: reminder.content.staleDate, relevanceScore: 2))
        }
        if let memo = memoActivity {
            var state = memo.content.state
            let showsCalendar = SharedAppGroup.defaults.bool(forKey: SharedAppGroup.Keys.memoShowsCalendar)
            state.showsCalendar = showsCalendar
            state.monthEventDots = showsCalendar
                ? CalendarMonthDots.dots(monthOffset: state.calendarMonthOffset) : []
            await memo.update(ActivityContent(state: state, staleDate: memo.content.staleDate, relevanceScore: 3))
        }
        if let schedule = scheduleActivity {
            let prev = schedule.content.state
            // 예시(목업)는 게시 시점 결정을 유지 — 재게시로 목업 캘린더가 꺼지지 않게.
            let showsCalendar = prev.isSample
                ? (prev.showsCalendar ?? false)
                : SharedAppGroup.defaults.bool(forKey: SharedAppGroup.Keys.scheduleShowsCalendar)
            // 게시된(cap됐을 수 있는) days가 아니라 보관해 둔 원본에서 다시 계산 — 껐다 켤 때 복원.
            let source = lastScheduleDays.isEmpty ? prev.days : lastScheduleDays
            let monthDots = showsCalendar && !prev.isSample
                ? CalendarMonthDots.dots(monthOffset: prev.calendarMonthOffset) : []
            var state = Self.fittedScheduleState(days: source, todayCount: prev.todayCount, weekEventDots: prev.weekEventDots, monthEventDots: monthDots)
            state.calendarMonthOffset = prev.calendarMonthOffset
            state.showsCalendar = showsCalendar
            state.isSample = prev.isSample
            await schedule.update(ActivityContent(state: state, staleDate: schedule.content.staleDate, relevanceScore: 2))
        }
    }
}
