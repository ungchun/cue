//
//  ReminderView.swift
//  cue / Presentation
//

import SwiftUI
import UIKit

/// 할일 탭 화면 — 선택된 리스트의 미완료 항목을 보여주고 완료 토글을 제공한다.
struct ReminderView: View {
    let viewModel: ReminderViewModel

    @State private var newTitle = ""
    @State private var newMemo = ""
    @State private var showingDetail = false
    @State private var editingReminder: Reminder?

    // 새 입력 행 — title/memo 각자 focus 추적. 둘 다 풀리면 add 시도.
    @State private var newTitleFocused = false
    @State private var newMemoFocused = false

    // 기존 항목 인라인 편집 — 한 번에 하나만 편집한다.
    @State private var editingReminderID: String?
    @State private var editingTitle = ""
    @State private var editingMemo = ""
    @State private var editTitleFocused = false
    @State private var editMemoFocused = false

    // 새 입력 행에서 ⓘ를 눌렀을 때, 이어지는 포커스 해제로 자동 add가 일어나지 않도록 한 번 억제한다.
    @State private var suppressNewRowAutoSubmit = false

    // 체크 → 0.5초 정지 → 토글 적용. 그 사이 동그라미는 채워진 체크마크로 보인다.
    // 대기 중 다시 탭하면 취소(iOS 미리알림과 동일).
    @State private var pendingCompletionIDs: Set<String> = []


    // 인라인 편집 row swap 진행 중인지 — 이전 view의 textViewDidEndEditing이 binding을
    // false로 떨어뜨리는 부작용을 차단하기 위한 가드. swap 중엔 editTitleFocused = false가
    // 들어와도 즉시 true로 복원해 새 row의 GrowingTextView가 키보드를 유지하게 한다.
    @State private var swappingInlineEdit = false

    // 옵션 메뉴에서 트리거되는 모달들 — 시트 내용은 다음 사이클에서.
    @State private var showingNewListSheet = false
    @State private var showingListInfoSheet = false
    @State private var showingDeleteListConfirmation = false

    // 스크롤로 본문 large title이 가려졌는지 — 가려지면 navigation bar에 inline title 표시.
    @State private var showsInlineTitle = false

    // `.all` 모드에서 어느 섹션의 입력 row가 활성인지. nil이면 모두 placeholder.
    // 한 번에 하나만 active — newReminderRow가 단일 state 기반이라 다중 활성 불가하므로
    // active한 섹션에만 진짜 입력 row를 mount하고 나머진 placeholder로 표시.
    @State private var activeNewRowListID: String?

    // 좌상단 "미리 알림" 버튼 — Apple Reminders 앱 호출용 SwiftUI 환경 핸들.
    @Environment(\.openURL) private var openURL

    var body: some View {
        content
            // 시스템 large title은 색을 selection별로 동적 변경할 수 없어 inline 모드로
            // 숨기고 List 안 첫 row(`listTitleRow`)에 직접 그린다. 스크롤하면 컨텐츠와
            // 함께 위로 사라지고, 가려진 시점에 navigation bar 중앙 inline title이 채워진다.
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(showsInlineTitle ? currentTitle : "")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    openRemindersAppButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    optionsMenu
                }
            }
            .task { await viewModel.onAppear() }
            .alert("오류", isPresented: errorBinding) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showingDetail) {
                // 생성 — 입력 행에 적힌 제목·메모를 초기값으로 시트에 흘려준다.
                ReminderDetailSheet(title: newTitle, memo: newMemo) { draft in
                    saveNewReminder(draft: draft)
                }
            }
            .sheet(item: $editingReminder) { reminder in
                // 수정 — 인라인 편집 값(이미 reminder에 스냅샷됨)을 초기값으로 넘기고, 완료 시 update 호출.
                ReminderDetailSheet(
                    title: reminder.title,
                    memo: reminder.notes ?? "",
                    dueDate: reminder.dueDate,
                    includesTime: reminder.includesTime
                ) { draft in
                    saveEdit(reminderID: reminder.id, draft: draft)
                }
            }
            // 인라인 편집의 두 필드 사이 이동은 잠깐 둘 다 false가 될 수 있어 80ms 지연 후 재확인.
            .onChange(of: editTitleFocused) { _, _ in scheduleEditCommit() }
            .onChange(of: editMemoFocused) { _, _ in scheduleEditCommit() }
            .onChange(of: newTitleFocused) { _, _ in scheduleNewCommit() }
            .onChange(of: newMemoFocused) { _, _ in scheduleNewCommit() }
            // 새로운 목록 — 빈 폼 + 기본 색.
            .sheet(isPresented: $showingNewListSheet) {
                ListEditorSheet(mode: .new) { title, colorHex in
                    Task { await viewModel.addList(title: title, colorHex: colorHex) }
                }
            }
            // 목록 정보 보기 — 현재 선택된 리스트의 값을 초기값으로.
            // selectedList가 nil이면 메뉴 항목이 의미 없으므로 sheet도 의미 없다 — guard.
            .sheet(isPresented: $showingListInfoSheet) {
                if let list = viewModel.selectedList {
                    ListEditorSheet(mode: .edit(list)) { title, colorHex in
                        Task { await viewModel.updateList(listID: list.id, title: title, colorHex: colorHex) }
                    }
                }
            }
            // 목록 삭제 확인 — 안에 있는 모든 미리알림도 EventKit이 함께 제거한다.
            .alert(
                "'\(viewModel.selectedList?.title ?? "")' 삭제",
                isPresented: $showingDeleteListConfirmation
            ) {
                Button("취소", role: .cancel) {}
                Button("삭제", role: .destructive) {
                    guard let listID = viewModel.selectedListID else { return }
                    Task { await viewModel.deleteList(listID: listID) }
                }
            } message: {
                Text("이 목록과 안에 있는 모든 미리알림이 삭제됩니다.")
            }
    }

    /// 좌측 상단 — Apple Reminders 앱으로 점프하는 텍스트 버튼.
    /// `x-apple-reminderkit://` 스킴으로 시스템 미리 알림 앱을 연다. 시스템이 처리할 수
    /// 없으면 SwiftUI `openURL`이 조용히 무시한다(별도 fallback 없음).
    private var openRemindersAppButton: some View {
        Button {
            if let url = URL(string: "x-apple-reminderkit://") {
                openURL(url)
            }
        } label: {
            Text("미리 알림")
        }
    }

    /// 우측 상단 옵션 메뉴 — 완료된 항목 토글, 목록 CRUD 진입.
    /// `Section` 사이에 SwiftUI Menu가 자동으로 구분선을 그려준다(iOS native 패턴).
    /// 시트·삭제 액션의 실제 백엔드는 다음 사이클에서 — 지금은 UI 진입까지만.
    private var optionsMenu: some View {
        Menu {
            // 오늘/예정은 마감일 필터라 완료 항목 매핑이 모호 — 토글 자체를 숨겨 혼동을 줄인다.
            if canToggleCompleted {
                Button {
                    viewModel.showsCompleted.toggle()
                } label: {
                    Label(
                        viewModel.showsCompleted ? "완료된 항목 숨기기" : "완료된 항목 보기",
                        systemImage: viewModel.showsCompleted ? "eye.slash" : "eye"
                    )
                }
            }

            Section {
                Button {
                    showingNewListSheet = true
                } label: {
                    Label("새로운 목록", systemImage: "plus")
                }
                Button {
                    showingListInfoSheet = true
                } label: {
                    Label("목록 정보 보기", systemImage: "info.circle")
                }
            }

            Section {
                Button(role: .destructive) {
                    showingDeleteListConfirmation = true
                } label: {
                    Label("목록 삭제", systemImage: "trash")
                }
                // 선택된 리스트가 없으면 삭제할 게 없음.
                .disabled(viewModel.selectedList == nil)
            }
        } label: {
            Image(systemName: "ellipsis")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.access {
        case .notDetermined:
            ProgressView()
        case .denied:
            deniedView
        case .granted:
            reminderList
        }
    }

    private var deniedView: some View {
        ContentUnavailableView {
            Label("미리 알림 접근 필요", systemImage: "lock")
        } actions: {
            Button("설정 열기") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .padding(.top, Spacing.sm)
        }
    }

    private var reminderList: some View {
        List {
            listTitleRow
            let isAllMode: Bool = {
                if case .systemFilter(.all) = viewModel.selection { return true }
                return false
            }()
            if isAllMode {
                allModeContent
            } else {
                singleModeContent
            }

            // `.all` 모드는 완료 항목을 각 섹션 내부에 그리므로 외곽 completedSection은 생략.
            if viewModel.showsCompleted, !isAllMode {
                completedSection
            }
        }
        .listStyle(.plain)
        .listRowSpacing(Spacing.zero)
        .listSectionSpacing(Spacing.zero)
        // 시스템 기본 row 최소 높이(44pt)를 0으로 깎아 row가 컨텐츠 자체 높이로 줄어든다.
        // horizontal inset은 시스템 기본 유지 — `.listRowInsets`처럼 좌우까지 강제하지 않는다.
        .environment(\.defaultMinListRowHeight, Spacing.zero)
        .animation(.easeInOut(duration: 0.25), value: viewModel.visibleReminders.map(\.id))
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y > 40
        } action: { _, newValue in
            showsInlineTitle = newValue
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        // 칩 바는 더 이상 여기 safeAreaInset에 없다 — `RootView`의
        // `tabViewBottomAccessory`로 이동했다. 스크롤에 따라 탭바와 시각적으로
        // 분리·통합되는 Apple Music 미니 플레이어 패턴(iOS 26).
    }

    /// 리스트/오늘/예정 selection 본문 — 단일 ForEach + 입력 행.
    @ViewBuilder
    private var singleModeContent: some View {
        remindersForEach(viewModel.visibleReminders)
        newReminderRow
            .listRowSeparator(.hidden)
    }

    /// `.all` selection 본문 — 리스트별 섹션 그루핑. SwiftUI `Section` + `.listStyle(.plain)`
    /// 조합으로 섹션 헤더가 자동 sticky(공중에 떠 있는 형태)로 동작한다.
    /// 각 섹션 끝에 입력 row가 있고 — `activeNewRowListID == section.list.id`인 섹션만
    /// 진짜 `newReminderRow`(GrowingTextView mount)를 그리고, 나머진 placeholder.
    /// 입력 row 다음에 섹션 끝 디바이더 1pt.
    @ViewBuilder
    private var allModeContent: some View {
        ForEach(viewModel.allModeSections, id: \.list.id) { section in
            Section {
                remindersForEach(section.active)
                // 그 리스트의 완료 항목들 — showsCompleted OFF면 ViewModel이 빈 배열로 줘서 자동 생략.
                ForEach(section.completed) { reminder in
                    completedReminderRow(reminder)
                        .listRowSeparator(.hidden)
                        .listRowInsets(rowInsets)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.delete(reminder) }
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                }
                if activeNewRowListID == section.list.id {
                    newReminderRow
                        .listRowSeparator(.hidden)
                } else {
                    newRowPlaceholder(forListID: section.list.id)
                        .listRowSeparator(.hidden)
                }
                Color(.separator)
                    .frame(height: 1)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, Spacing.zero)
            } header: {
                sectionHeader(for: section.list)
            }
        }
    }

    /// 비활성 섹션의 입력 row placeholder — `circle.dotted` 아이콘만. 텍스트는 두지 않는다.
    /// 탭하면 `activeNewRowListID`가 그 listID로 바뀌어 진짜 입력 row가 mount되고
    /// 다음 runloop에 포커스가 이동한다. 행 전체가 hit area.
    private func newRowPlaceholder(forListID listID: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: circleTextSpacing) {
            Image(systemName: "circle.dotted")
                .font(.title2.weight(.thin))
                .foregroundStyle(.tertiary)
                .frame(
                    width: UIFont.preferredFont(forTextStyle: .body).lineHeight,
                    height: UIFont.preferredFont(forTextStyle: .body).lineHeight
                )
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .listRowInsets(rowInsets)
        .onTapGesture {
            activateNewRow(forListID: listID)
        }
    }

    /// placeholder 탭 처리 — active를 그 섹션으로 옮기고 다음 runloop에서 포커스 set.
    /// mount 직전에 focus를 true로 두면 새로 그려질 GrowingTextView가 이를 받아 keyboard 띄움.
    private func activateNewRow(forListID listID: String) {
        activeNewRowListID = listID
        DispatchQueue.main.async {
            newTitleFocused = true
        }
    }

    /// reminder row + swipe(삭제) — single/all 모드 공통.
    @ViewBuilder
    private func remindersForEach(_ reminders: [Reminder]) -> some View {
        ForEach(reminders) { reminder in
            reminderRow(reminder)
                .listRowSeparator(.hidden)
                .listRowInsets(rowInsets)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task {
                            await flushInlineEditAwaiting()
                            try? await Task.sleep(for: .milliseconds(120))
                            await viewModel.delete(reminder)
                        }
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
        }
    }

    /// `.all` 모드 섹션 헤더 — 리스트 이름을 그 리스트 색으로, 폰트는 large title보다 한 단계 작게.
    private func sectionHeader(for list: ReminderList) -> some View {
        Text(list.title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(metaColor(forListColorHex: list.colorHex))
    }

    /// List 안에 직접 그리는 large title — selection별 라벨·색을 적용. 스크롤되면
    /// 컨텐츠와 함께 위로 사라지고 navigation bar inline title이 채워진다.
    /// (라이브 액티비티 토글은 우하단 메시지 버튼으로 이동.)
    private var listTitleRow: some View {
        HStack(alignment: .center) {
            Text(currentTitle)
                .font(.largeTitle.bold())
                .foregroundStyle(currentTitleColor)
            Spacer()
            FloatingMessageButton {
                await viewModel.toggleLiveActivity(listTitle: currentTitle)
            }
        }
        .listRowSeparator(.hidden)
        // leading은 다른 행과 동일(rowInsets)하게 맞추되, trailing만 md로 줄여 LIVE 버튼
        // 오른쪽 끝을 상단 툴바 버튼과 맞춘다.
        .listRowInsets(.init(top: Spacing.sm + Spacing.xxs, leading: Spacing.lg, bottom: Spacing.sm + Spacing.xxs, trailing: Spacing.md))
    }

    /// 현재 selection의 large title 라벨 — 사용자 리스트면 그 이름, 시스템 필터면 필터 라벨.
    private var currentTitle: String {
        switch viewModel.selection {
        case .list: return viewModel.selectedList?.title ?? ""
        case .systemFilter(let filter): return filter.title
        case .none: return ""
        }
    }

    /// 현재 selection의 large title 색 — 시스템 필터는 Apple Reminders 패턴을 따른
    /// 의미별 시스템 컬러(오늘=accent / 예정=red / 전체=gray), 사용자 리스트는 그 리스트
    /// EventKit 캘린더 색, 없으면 `.primary`. 시스템 필터 색은 EventKit에 없어 자체 매핑.
    private var currentTitleColor: Color {
        switch viewModel.selection {
        case .list: return listColor ?? .primary
        case .systemFilter(.today): return Color.accentColor
        case .systemFilter(.scheduled): return Color.red
        case .systemFilter(.all): return Color.gray
        case .none: return .primary
        }
    }

    /// 옵션 메뉴의 "완료된 항목 보기" 토글 노출 여부.
    /// 오늘/예정은 dueDate 기반 필터라 "완료된 항목"의 의미가 모호하고 ViewModel도 그 두 모드에선
    /// 완료 항목을 비워 둔다 — 토글이 작동해도 시각 효과가 없으므로 메뉴에서 자체를 숨긴다.
    /// `.all`과 단일 리스트(`.list(id)`)에서만 노출.
    private var canToggleCompleted: Bool {
        switch viewModel.selection {
        case .systemFilter(.today), .systemFilter(.scheduled): return false
        default: return true
        }
    }

    /// 현재 선택된 리스트의 색 — EventKit calendar color에서 매핑된 hex 문자열을 Color로.
    /// 색이 없거나 잘못된 hex면 `nil` → 호출자가 fallback 색(.primary/.secondary 등)을 정함.
    private var listColor: Color? {
        guard let hex = viewModel.selectedList?.colorHex else { return nil }
        return Color(hex: hex)
    }

    /// 완료된 항목 섹션 — 입력 행 밑에 디바이더 + "완료됨" 헤더 + 완료된 항목들.
    /// 미완료 섹션과 같은 List 안에 그려야 스크롤·스와이프가 자연스럽게 이어진다.
    /// `.listStyle(.plain)`에선 Section header가 sticky가 되므로 일반 row로 헤더 그린다.
    @ViewBuilder
    private var completedSection: some View {
        // `Divider()`는 List row 안에서 세로 라인으로 잡힐 때가 있어 직접 1pt 가로 라인.
        // `Color(.separator)`는 iOS system 라인 색이라 light/dark 자동 대응.
        Color(.separator)
            .frame(height: 1)
            .listRowSeparator(.hidden)
        HStack(alignment: .lastTextBaseline) {
            Text("완료됨")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(viewModel.completedReminders.count)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .listRowSeparator(.hidden)

        ForEach(viewModel.completedReminders) { reminder in
            completedReminderRow(reminder)
                .listRowSeparator(.hidden)
                .listRowInsets(rowInsets)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await viewModel.delete(reminder) }
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
        }
    }

    /// 완료된 항목 행 — 채워진 동그라미 + secondary 색 텍스트.
    /// 동그라미 탭 → 미완료로 토글(0.5초 지연 동작은 미완료 행과 동일).
    private func completedReminderRow(_ reminder: Reminder) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(alignment: .top, spacing: circleTextSpacing) {
                Button {
                    tapCompletionToggle(reminder)
                } label: {
                    completionIcon(for: reminder)
                }
                .buttonStyle(.plain)

                Text(reminder.title)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let dueDate = reminder.dueDate {
                Text(dueDateText(dueDate))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, titleIndent)
            }
        }
    }

    /// 미리알림 한 줄 — 통합 view tree. 모든 row에 title GrowingTextView가 항상 alive로 유지돼
    /// row swap 시 dispose 없이 first responder transfer가 일어나 키보드가 안 내려간다.
    /// editing 중인 row만 editable 상태(focus 가능, memo 칸·ⓘ 추가)이고, 나머지 row의 title
    /// GrowingTextView는 reminder.title을 constant binding으로 받아 disabled.
    private func reminderRow(_ reminder: Reminder) -> some View {
        let isEditing = editingReminderID == reminder.id
        return VStack(alignment: .leading, spacing: Spacing.xxs) {
            // 첫 줄 — 동그라미 + 제목(+ 편집 중일 때 ⓘ). `.top` 정렬 + image가 body lineHeight
            // 정사각형 frame이라 image center가 첫 줄 line box center에 자동 정렬된다.
            HStack(alignment: .top, spacing: circleTextSpacing) {
                Button {
                    tapCompletionToggle(reminder)
                } label: {
                    completionIcon(for: reminder)
                }
                .buttonStyle(.plain)

                // title GrowingTextView — 모든 row에 항상 mount. dispose 없음 → 키보드 transfer 가능.
                GrowingTextView(
                    text: titleBinding(for: reminder),
                    isFocused: focusBinding(for: reminder, field: .title),
                    font: .preferredFont(forTextStyle: .body),
                    textColor: .label,
                    submitOnReturn: true
                )
                // swap 중엔 모든 row enabled — `.disabled` 변경이 UIKit에 disabled view의
                // first responder를 자동 resign 시키는 부작용을 일으켜 키보드를 내림.
                // swap 끝나면(250ms) editing 아닌 row만 disabled로 — 사용자 추가 텍스트
                // 입력 차단. binding setter가 editingReminderID 체크라 어차피 noop이지만
                // UX 일관성 위해.
                .disabled(swappingInlineEdit ? false : !isEditing)
                .frame(maxWidth: .infinity, alignment: .leading)

                if isEditing {
                    Button {
                        openDetailSheet(for: reminder)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundStyle(listColor ?? Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 둘째 줄 — 메모(편집 + focus 중일 때) 또는 메타. titleIndent로 동그라미 영역만큼
            // 들여쓰기 → 제목 leading edge에 정렬.
            Group {
                if isEditing && (editTitleFocused || editMemoFocused) {
                    GrowingTextView(
                        text: $editingMemo,
                        isFocused: $editMemoFocused,
                        placeholder: "메모 추가",
                        font: .preferredFont(forTextStyle: .callout),
                        textColor: .secondaryLabel,
                        submitOnReturn: true
                    )
                } else {
                    metaRow(for: reminder)
                }
            }
            .padding(.leading, titleIndent)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing { startInlineEdit(reminder) }
        }
    }

    /// 항목 둘째 줄 메타. 표시할 라벨이 하나라도 있을 때만 그린다.
    /// - **리스트이름** (그 리스트 색): 오늘/예정에서만 표시. 전체는 섹션 헤더가
    ///   리스트이름을 큰 글씨로 보여주므로 row 메타에서는 중복 제거.
    /// - **마감일/시간**: 마감일이 있으면 항상 (지났으면 빨강)
    /// - **↻ 반복**: 반복 규칙이 있으면 selection 모드 무관 항상
    @ViewBuilder
    private func metaRow(for reminder: Reminder) -> some View {
        if reminder.dueDate != nil || reminder.recurrence != nil || showsListNameInMeta {
            HStack(spacing: Spacing.sm) {
                if showsListNameInMeta, let list = list(for: reminder) {
                    Text(list.title)
                        .foregroundStyle(metaColor(forListColorHex: list.colorHex))
                }
                if let dueDate = reminder.dueDate {
                    Text(dueDateText(dueDate))
                        .foregroundStyle(isOverdue(dueDate) ? Color.red : Color.secondary)
                }
                if let recurrence = reminder.recurrence {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "repeat")
                        Text(recurrenceLabel(recurrence))
                    }
                    .foregroundStyle(Color.secondary)
                }
            }
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 메타 row에 리스트 이름을 표시할지 — 오늘/예정에서만 true. 전체는 섹션 헤더에
    /// 이미 리스트이름이 있어 row 메타 표시는 중복.
    private var showsListNameInMeta: Bool {
        switch viewModel.selection {
        case .systemFilter(.today), .systemFilter(.scheduled): return true
        default: return false
        }
    }

    /// 현재 selection이 시스템 필터(오늘/예정/전체)면 true. 메타 row의 풍부도 분기에 쓰인다.
    private var isSystemFilterMode: Bool {
        if case .systemFilter = viewModel.selection { return true }
        return false
    }

    /// `reminder`가 속한 리스트(있다면) — 메타 라벨용.
    private func list(for reminder: Reminder) -> ReminderList? {
        viewModel.lists.first { $0.id == reminder.listID }
    }

    /// 리스트 colorHex → Color. 없거나 hex 파싱 실패면 `.secondary` fallback.
    private func metaColor(forListColorHex hex: String?) -> Color {
        guard let hex, let color = Color(hex: hex) else { return Color.secondary }
        return color
    }

    /// 반복 규칙 한국어 라벨. interval=1이면 매일/매주/매월/매년,
    /// 아니면 "N일/주/개월/년 마다".
    private func recurrenceLabel(_ rule: RecurrenceRule) -> String {
        if rule.interval == 1 {
            switch rule.frequency {
            case .daily: return "매일"
            case .weekly: return "매주"
            case .monthly: return "매월"
            case .yearly: return "매년"
            }
        }
        let unit: String
        switch rule.frequency {
        case .daily: unit = "일"
        case .weekly: unit = "주"
        case .monthly: unit = "개월"
        case .yearly: unit = "년"
        }
        return "\(rule.interval)\(unit)마다"
    }

    /// 인라인 편집 row 식별용 field.
    private enum InlineField { case title, memo }

    /// row의 title binding — editing 중인 row만 mutable `editingTitle`에 연결,
    /// 다른 row는 reminder.title을 constant로 (set은 noop).
    private func titleBinding(for reminder: Reminder) -> Binding<String> {
        Binding(
            get: { editingReminderID == reminder.id ? editingTitle : reminder.title },
            set: { newValue in
                if editingReminderID == reminder.id { editingTitle = newValue }
            }
        )
    }

    /// newReminderRow title의 isFocused binding — setter 안에서 sync로 인라인 편집을 정리한다.
    /// 이게 onChange보다 빠른 시점이라 inline row의 update.async become이 호출되기 전에
    /// editingReminderID를 nil로 만들어 inline row의 focusBinding이 false 반환.
    private var newRowFocusBinding: Binding<Bool> {
        Binding(
            get: { newTitleFocused },
            set: { newValue in
                if newValue, editingReminderID != nil {
                    let snapshot = capturedInlineEdit()
                    editingReminderID = nil
                    editTitleFocused = false
                    editMemoFocused = false
                    backgroundCommit(snapshot)
                }
                newTitleFocused = newValue
            }
        )
    }

    /// row의 isFocused binding — editing 중인 row만 actual focus state에 연결.
    private func focusBinding(for reminder: Reminder, field: InlineField) -> Binding<Bool> {
        Binding(
            get: {
                guard editingReminderID == reminder.id else { return false }
                return field == .title ? editTitleFocused : editMemoFocused
            },
            set: { newValue in
                guard editingReminderID == reminder.id else { return }
                if field == .title { editTitleFocused = newValue }
                else { editMemoFocused = newValue }
            }
        )
    }

    /// 리스트 맨 아래 새 할일 입력 행 — 제목·메모를 직접 입력한다.
    /// 포커스 시 메모 칸과 ⓘ 버튼이 나타난다. 두 입력은 멀티라인 GrowingTextView.
    /// 두 focus 모두 풀리면 자동 add(80ms 지연 후 재확인). ⓘ로는 세부사항 시트.
    private var newReminderRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(alignment: .top, spacing: circleTextSpacing) {
                Image(systemName: "circle.dotted")
                    .font(.title2.weight(.thin))
                    .foregroundStyle(.secondary)
                    .frame(
                        width: UIFont.preferredFont(forTextStyle: .body).lineHeight,
                        height: UIFont.preferredFont(forTextStyle: .body).lineHeight
                    )

                GrowingTextView(
                    text: $newTitle,
                    // setter에서 inline 편집 정리를 sync로 처리 — onChange로 미루면 inline row의
                    // update.async become이 stale state로 먼저 처리되어 first responder를 잠깐 끌어감.
                    isFocused: newRowFocusBinding,
                    font: .preferredFont(forTextStyle: .body),
                    textColor: .label,
                    submitOnReturn: true
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                if newTitleFocused || newMemoFocused {
                    Button {
                        suppressNewRowAutoSubmit = true
                        showingDetail = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundStyle(listColor ?? Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            if newTitleFocused || newMemoFocused {
                GrowingTextView(
                    text: $newMemo,
                    isFocused: $newMemoFocused,
                    placeholder: "메모 추가",
                    font: .preferredFont(forTextStyle: .callout),
                    textColor: .secondaryLabel,
                    submitOnReturn: true
                )
                .padding(.leading, titleIndent)
            }
        }
        .listRowInsets(rowInsets)
    }

    /// 모든 행(큰 제목·항목·완료·입력·섹션 헤더) 공통 인셋 — 좌우 `Spacing.lg`(24)로 같은
    /// 세로 기준선에 정렬. 한 곳에서 관리해 패딩을 바꿀 때 전 행이 함께 따라온다.
    private var rowInsets: EdgeInsets {
        .init(top: Spacing.sm + Spacing.xxs, leading: Spacing.lg, bottom: Spacing.sm + Spacing.xxs, trailing: Spacing.lg)
    }

    /// 동그라미와 텍스트 사이 spacing — 모든 row에서 일관되게 사용. 토큰 합성으로 표현.
    private var circleTextSpacing: CGFloat {
        Spacing.sm + Spacing.xs + Spacing.xxs
    }

    /// 메타·메모를 제목 leading edge에 정렬하기 위한 들여쓰기 폭.
    /// 동그라미 frame(body lineHeight × lineHeight) + circleTextSpacing.
    /// UIFont 메트릭 + 토큰 합성이라 Dynamic Type / spacing 변경 시 자동 추종 — 매직값 없음.
    private var titleIndent: CGFloat {
        UIFont.preferredFont(forTextStyle: .body).lineHeight + circleTextSpacing
    }

    /// 완료 동그라미 — 양방향 토글 대응. pending이면 토글 후 상태를, 아니면 현재 상태를 표시한다.
    /// 완료 상태는 `largecircle.fill.circle`(외곽 원 + 안 작은 점) + **reminder가 속한 리스트 색**,
    /// 미완료는 빈 `circle` + secondary 회색 — 미리알림 앱과 동일.
    /// `.all` 모드처럼 selection이 특정 리스트가 아닐 때도 각 row의 리스트 색이 그대로 따라온다.
    private func completionIcon(for reminder: Reminder) -> some View {
        let pending = pendingCompletionIDs.contains(reminder.id)
        let showCompleted = pending ? !reminder.isCompleted : reminder.isCompleted
        let reminderListColor: Color? = list(for: reminder)?.colorHex.flatMap(Color.init(hex:))
        let tint: Color = showCompleted ? (reminderListColor ?? .accentColor) : .secondary
        return Image(systemName: showCompleted ? "largecircle.fill.circle" : "circle")
            .font(.title2.weight(.thin))
            .foregroundStyle(tint)
            // body 한 줄 line height × line height 정사각형으로 image 영역을 강제.
            // → image center가 body 첫 줄 line box center에 자동 정렬되고(HStack `.top` 조합),
            //   동시에 메타/메모의 `.padding(.leading, titleIndent)`가 정확히 이 영역 옆에서 시작한다.
            //   title2 image가 frame보다 살짝 크지만 layout 기준은 frame.
            .frame(
                width: UIFont.preferredFont(forTextStyle: .body).lineHeight,
                height: UIFont.preferredFont(forTextStyle: .body).lineHeight
            )
    }

    /// 완료 토글을 0.5초 지연 후 적용한다 — 즉시 사라지지 않게 잠깐 멈춰서
    /// 사용자가 자신의 탭을 시각적으로 확인할 시간을 준다(iOS 미리알림과 동일).
    /// 대기 중 다시 탭하면 취소되어 토글되지 않는다.
    private func tapCompletionToggle(_ reminder: Reminder) {
        if pendingCompletionIDs.contains(reminder.id) {
            pendingCompletionIDs.remove(reminder.id)
            return
        }
        pendingCompletionIDs.insert(reminder.id)
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            // 사용자가 대기 중 다시 탭해 취소했으면 적용 안 함.
            guard pendingCompletionIDs.contains(reminder.id) else { return }
            // 인라인 편집 commit(=update fetch)을 await으로 완전히 끝내고, dispose 한 turn 양보 후
            // toggle. 두 mutation이 거의 동시에 ForEach diff를 일으켜 first responder race로 죽던
            // 문제를 strict sequential로 차단한다.
            await flushInlineEditAwaiting()
            try? await Task.sleep(for: .milliseconds(120))
            // pending 해제는 toggle 이후 — "체크 해제 → 사라짐" 깜빡임 방지.
            await viewModel.toggle(reminder)
            pendingCompletionIDs.remove(reminder.id)
        }
    }

    /// 인라인 편집 commit + update fetch까지 await으로 끝내고 돌아온다.
    /// caller가 또 다른 mutation(toggle/delete/start new edit 등)을 일으키기 직전에 부르면,
    /// 두 fetch가 거의 동시에 ForEach diff를 일으켜 first responder가 deleted cell에 갇히는
    /// UICollectionView assertion으로 죽는 race를 strict-sequential로 차단한다.
    @MainActor
    private func flushInlineEditAwaiting() async {
        guard let id = editingReminderID,
              let reminder = viewModel.allReminders.first(where: { $0.id == id }) else {
            // 편집 대상이 사라졌으면 inline editing state만 정리.
            editingReminderID = nil
            editTitleFocused = false
            editMemoFocused = false
            return
        }
        let trimmed = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalMemo = reminder.notes ?? ""
        let memo = editingMemo

        editingReminderID = nil
        editTitleFocused = false
        editMemoFocused = false

        guard !trimmed.isEmpty,
              trimmed != reminder.title || memo != originalMemo else { return }

        await viewModel.update(
            reminderID: reminder.id,
            title: trimmed,
            notes: memo,
            dueDate: reminder.dueDate,
            includesTime: reminder.includesTime
        )
    }

    /// 인라인 편집을 시작한다 — 기존 값으로 버퍼를 채우고 제목에 포커스.
    /// 다른 행을 편집 중이었다면 먼저 그쪽을 커밋한다.
    ///
    /// **키보드 유지 시퀀스** (편집 중 다른 row 탭):
    /// 1) 이전 편집의 update fetch까지 await(focus state는 유지)
    /// 2) editingReminderID·title·memo만 swap. editTitleFocused는 그대로 true.
    /// 새 row의 GrowingTextView가 mount되며 `makeUIView`가 isFocused=true를 보고 즉시
    /// `becomeFirstResponder`. 이전 UITextView dispose와 같은 RunLoop tick에 일어나
    /// UIKit이 first responder를 자연 transfer → 키보드가 안 내려간다.
    /// 인라인 편집을 시작한다 — view swap을 sync로 즉시, 이전 편집은 background commit.
    /// `await commit`으로 보내면 EventKit fetch 시간(200~500ms)이 노출돼 사용자가 키보드
    /// 한 번 내려갔다 올라오는 두 단계로 본다. sync swap이면 같은 RunLoop tick에 first
    /// responder transfer가 일어나 키보드 유지.
    private func startInlineEdit(_ reminder: Reminder) {
        if editingReminderID == reminder.id { return }
        let previous = capturedInlineEdit()
        swappingInlineEdit = true
        editingReminderID = reminder.id
        editingTitle = reminder.title
        editingMemo = reminder.notes ?? ""
        editTitleFocused = true
        backgroundCommit(previous)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            swappingInlineEdit = false
        }
    }

    /// 현재 인라인 편집 state를 snapshot으로 떠 캡쳐 — sync swap 직전 호출.
    private func capturedInlineEdit() -> (id: String, title: String, memo: String)? {
        guard let id = editingReminderID else { return nil }
        return (id, editingTitle, editingMemo)
    }

    /// snapshot한 인라인 편집을 background에서 commit — view swap 후 호출. fetch가 ForEach
    /// diff를 일으켜도 row identity(ID)가 유지돼 view dispose 없음 → race 없음.
    private func backgroundCommit(_ snapshot: (id: String, title: String, memo: String)?) {
        guard let snapshot,
              let previous = viewModel.allReminders.first(where: { $0.id == snapshot.id })
        else { return }
        let trimmed = snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalMemo = previous.notes ?? ""
        guard !trimmed.isEmpty,
              trimmed != previous.title || snapshot.memo != originalMemo else { return }
        Task {
            await viewModel.update(
                reminderID: previous.id, title: trimmed, notes: snapshot.memo,
                dueDate: previous.dueDate, includesTime: previous.includesTime
            )
        }
    }

    /// 인라인 편집을 마감한다 — 변경 사항이 있을 때만 update를 호출한다.
    /// 빈 제목은 무효 처리(원래 값 유지).
    private func commitInlineEdit(_ reminder: Reminder) {
        let trimmed = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalMemo = reminder.notes ?? ""
        let memo = editingMemo

        editingReminderID = nil
        editTitleFocused = false
        editMemoFocused = false

        guard !trimmed.isEmpty else { return }
        guard trimmed != reminder.title || memo != originalMemo else { return }

        Task {
            await viewModel.update(
                reminderID: reminder.id,
                title: trimmed,
                notes: memo,
                dueDate: reminder.dueDate,
                includesTime: reminder.includesTime
            )
        }
    }

    /// 인라인 편집 중 ⓘ를 누르면 — 친 값을 시트 초기값으로 넘기고 시트를 연다.
    /// (시트 완료 시 update가 한 번에 일어나므로 인라인 update는 하지 않는다.)
    /// `startInlineEdit`과 같은 race 차단 시퀀스 — focus 양보 → view swap → sheet open.
    private func openDetailSheet(for reminder: Reminder) {
        var snapshot = reminder
        snapshot.title = editingTitle
        snapshot.notes = editingMemo

        Task { @MainActor in
            if editTitleFocused || editMemoFocused {
                editTitleFocused = false
                editMemoFocused = false
                try? await Task.sleep(for: .milliseconds(80))
            }
            editingReminderID = nil
            // editing→readOnly view swap이 UITextView를 dispose할 시간을 준 뒤 시트 열기.
            try? await Task.sleep(for: .milliseconds(120))
            editingReminder = snapshot
        }
    }

    /// 인라인 편집의 두 GrowingTextView 사이 focus 이동은 잠깐 둘 다 false가 될 수 있다.
    /// 80ms 지연 후 둘 다 여전히 false면 진짜 commit.
    private func scheduleEditCommit() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            guard !editTitleFocused, !editMemoFocused,
                  let id = editingReminderID,
                  let reminder = viewModel.allReminders.first(where: { $0.id == id })
            else { return }
            commitInlineEdit(reminder)
        }
    }

    /// 새 입력 행의 두 GrowingTextView 사이 focus 이동도 동일 패턴.
    /// 80ms 지연 후 둘 다 풀려 있으면 add 시도. ⓘ 경로는 가드로 한 번 건너뜀.
    private func scheduleNewCommit() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            guard !newTitleFocused, !newMemoFocused else { return }
            if suppressNewRowAutoSubmit {
                suppressNewRowAutoSubmit = false
                return
            }
            submitNewReminder()
        }
    }

    /// 새 입력 행을 마감한다 — 포커스가 빠질 때 자동 호출. 제목이 비어 있으면 무시한다.
    /// `.all` 모드에서 active 섹션이 있으면 그 listID로, 아니면 ViewModel의 default 매칭.
    private func submitNewReminder() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetID = activeNewRowListID
        guard !trimmed.isEmpty else {
            activeNewRowListID = nil
            return
        }
        let memo = newMemo
        clearNewRow()
        activeNewRowListID = nil
        Task { await viewModel.add(title: trimmed, notes: memo, toListID: targetID) }
    }

    /// 세부사항 시트(생성) 완료 — Draft를 풀어 add 호출하고 입력 행을 비운다.
    private func saveNewReminder(draft: ReminderDetailSheet.Draft) {
        let trimmed = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let memo = draft.memo
        let targetID = activeNewRowListID
        clearNewRow()
        activeNewRowListID = nil
        Task {
            await viewModel.add(
                title: trimmed, notes: memo,
                dueDate: draft.dueDate, includesTime: draft.includesTime,
                toListID: targetID
            )
        }
    }

    /// 세부사항 시트(수정) 완료 — Draft를 풀어 update 호출.
    private func saveEdit(reminderID: String, draft: ReminderDetailSheet.Draft) {
        let trimmed = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            await viewModel.update(
                reminderID: reminderID,
                title: trimmed,
                notes: draft.memo,
                dueDate: draft.dueDate,
                includesTime: draft.includesTime
            )
        }
    }

    /// 입력 행을 비운다.
    private func clearNewRow() {
        newTitle = ""
        newMemo = ""
    }

    /// 마감일 표시 문자열 — 오늘·내일은 단어로, 그 외엔 "2026. 5. 29. 오후 6:00" 형태로.
    /// 기기 로케일과 무관하게 한국어로 보이도록 ko_KR을 명시한다.
    private func dueDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        let koLocale = Locale(identifier: "ko_KR")
        let time = date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened, locale: koLocale)
        )
        if calendar.isDateInToday(date) {
            return "오늘 \(time)"
        } else if calendar.isDateInTomorrow(date) {
            return "내일 \(time)"
        } else {
            return date.formatted(
                Date.FormatStyle(date: .numeric, time: .shortened, locale: koLocale)
            )
        }
    }

    /// 마감일이 현재 시각보다 지났으면 true — 지난 항목은 빨갛게 표시한다.
    private func isOverdue(_ date: Date) -> Bool {
        date < .now
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

#Preview {
    NavigationStack {
        ReminderView(viewModel: ReminderViewModel(dependencies: .preview))
    }
}


