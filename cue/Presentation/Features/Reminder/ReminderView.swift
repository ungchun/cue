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

    // 스크롤로 본문 large title이 가려졌는지 — 가려지면 navigation bar에 inline title 표시.
    @State private var showsInlineTitle = false

    // 옵션 메뉴에서 트리거되는 모달들 — 시트 내용은 다음 사이클에서.
    @State private var showingNewListSheet = false
    @State private var showingListInfoSheet = false
    @State private var showingDeleteListConfirmation = false

    var body: some View {
        content
            // 시스템 large title은 색을 항목별로 바꿀 수 없어 inline mode로 숨기고
            // List 안 첫 row에 직접 그린다(`listTitleRow`). 미리알림 앱과 동일 동작 —
            // 스크롤하면 title이 컨텐츠와 함께 위로 사라지고, 가려지는 시점에
            // navigation bar 중앙의 inline title이 채워진다(`showsInlineTitle`).
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(showsInlineTitle ? (viewModel.selectedList?.title ?? "") : "")
            .toolbar {
                // 뷰만 — 액션은 아직 없음.
                ToolbarItem(placement: .topBarLeading) {
                    listSelectionMenu
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

    /// 좌측 상단 — 사용자가 가진 미리알림 리스트(섹션)를 펼치는 메뉴.
    /// 각 항목 옆 `(n)`은 그 리스트의 **미완료** 개수. 현재 선택된 리스트는 leading 체크마크.
    ///
    /// SwiftUI Menu가 Button label 안 `Image`를 자동으로 menu item icon으로 띄워 opacity가
    /// 무시되므로 (모든 항목에 체크 보임), 선택 항목만 `Label(systemImage:)`로 두고 나머진
    /// 그냥 `Text`. iOS native Menu가 같은 그룹에 systemImage가 한 개라도 있으면 모든 항목에
    /// leading 자리를 예약해 들여쓰기 자동 정렬 + 선택 표시가 동시에 처리된다.
    private var listSelectionMenu: some View {
        Menu {
            ForEach(viewModel.lists) { list in
                Button {
                    viewModel.select(list)
                } label: {
                    let title = "\(list.title) (\(viewModel.incompleteCount(for: list)))"
                    if list.id == viewModel.selectedListID {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
            }
        } label: {
            Image(systemName: "list.bullet")
        }
    }

    /// 우측 상단 옵션 메뉴 — 완료된 항목 토글, 목록 CRUD 진입.
    /// `Section` 사이에 SwiftUI Menu가 자동으로 구분선을 그려준다(iOS native 패턴).
    /// 시트·삭제 액션의 실제 백엔드는 다음 사이클에서 — 지금은 UI 진입까지만.
    private var optionsMenu: some View {
        Menu {
            Button {
                viewModel.showsCompleted.toggle()
            } label: {
                Label(
                    viewModel.showsCompleted ? "완료된 항목 숨기기" : "완료된 항목 보기",
                    systemImage: viewModel.showsCompleted ? "eye.slash" : "eye"
                )
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
        } description: {
            Text("설정에서 cue의 미리 알림 접근을 허용해 주세요.")
        } actions: {
            Button("설정 열기") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private var reminderList: some View {
        List {
            listTitleRow
            ForEach(viewModel.visibleReminders) { reminder in
                reminderRow(reminder)
                    .listRowSeparator(.hidden)
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
            newReminderRow
                .listRowSeparator(.hidden)

            if viewModel.showsCompleted {
                completedSection
            }
        }
        .listStyle(.plain)
        .animation(.easeInOut(duration: 0.25), value: viewModel.visibleReminders.map(\.id))
        // 스크롤 시 키보드 즉시 닫음 → UITextView가 resign → isFocused 동기화로 새 입력/편집 포커스 해제.
        .scrollDismissesKeyboard(.immediately)
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
    }

    /// List 안 inline large title — 선택된 리스트 title을 그 리스트의 색으로 표시.
    /// 시스템 navigation large title은 색을 항목별로 변경할 수 없어 직접 그린다.
    /// 스크롤 시 컨텐츠와 함께 위로 사라진다(미리알림 앱과 동일).
    private var listTitleRow: some View {
        Text(viewModel.selectedList?.title ?? "")
            .font(AppFont.displayLarge)
            .foregroundStyle(listColor ?? .primary)
            .listRowSeparator(.hidden)
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
                .font(AppFont.titleLarge)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(viewModel.completedReminders.count)")
                .font(AppFont.bodySmall)
                .foregroundStyle(.secondary)
        }
        .listRowSeparator(.hidden)

        ForEach(viewModel.completedReminders) { reminder in
            completedReminderRow(reminder)
                .listRowSeparator(.hidden)
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
        HStack(alignment: .top, spacing: Spacing.sm) {
            Button {
                tapCompletionToggle(reminder)
            } label: {
                completionIcon(for: reminder)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(reminder.title)
                    .font(AppFont.bodyLarge)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let dueDate = reminder.dueDate {
                    Text(dueDateText(dueDate))
                        .font(AppFont.bodySmall)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 미리알림 한 줄 — 편집 모드 여부에 따라 정적 표시 또는 인라인 편집 행을 보여준다.
    @ViewBuilder
    private func reminderRow(_ reminder: Reminder) -> some View {
        if editingReminderID == reminder.id {
            editingReminderRow(reminder)
        } else {
            readOnlyReminderRow(reminder)
        }
    }

    /// 정적 표시 행 — 텍스트 영역 탭 → 인라인 편집으로 전환.
    /// 동그라미 Button은 별도 영역이라 자기 탭(완료 토글)만 처리하고 행 탭과 충돌 안 함.
    private func readOnlyReminderRow(_ reminder: Reminder) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Button {
                tapCompletionToggle(reminder)
            } label: {
                completionIcon(for: reminder)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(reminder.title)
                    .font(AppFont.bodyLarge)
                    .foregroundStyle(.primary)
                    // List row에서 Text가 한 줄로 잘리는 SwiftUI 동작을 막고 멀티라인 wrap 보장.
                    .fixedSize(horizontal: false, vertical: true)

                if let dueDate = reminder.dueDate {
                    Text(dueDateText(dueDate))
                        .font(AppFont.bodySmall)
                        .foregroundStyle(isOverdue(dueDate) ? Color.red : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                startInlineEdit(reminder)
            }
        }
    }

    /// 인라인 편집 행 — newReminderRow와 같은 모양. 제목·메모는 멀티라인 GrowingTextView.
    /// GrowingTextView는 UITextView 기반(textContainerInset=0)이라 leading SF Symbol과 정렬이 정확.
    /// HStack `.firstTextBaseline` + Image `.font(.body)`로 글자 baseline에 자연스럽게 매핑된다.
    private func editingReminderRow(_ reminder: Reminder) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Button {
                tapCompletionToggle(reminder)
            } label: {
                completionIcon(for: reminder)
                    .font(.body)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                GrowingTextView(
                    text: $editingTitle,
                    isFocused: $editTitleFocused,
                    font: .preferredFont(forTextStyle: .body),
                    textColor: .label,
                    submitOnReturn: true
                )
                GrowingTextView(
                    text: $editingMemo,
                    isFocused: $editMemoFocused,
                    placeholder: "메모 추가",
                    font: .preferredFont(forTextStyle: .callout),
                    textColor: .secondaryLabel,
                    submitOnReturn: true
                )
            }

            Spacer()
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

    /// 리스트 맨 아래 새 할일 입력 행 — 제목·메모를 직접 입력한다.
    /// 포커스 시 메모 칸과 ⓘ 버튼이 나타난다. 두 입력은 멀티라인 GrowingTextView.
    /// 두 focus 모두 풀리면 자동 add(80ms 지연 후 재확인). ⓘ로는 세부사항 시트.
    private var newReminderRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: "circle.dotted")
                .font(.body)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                GrowingTextView(
                    text: $newTitle,
                    isFocused: $newTitleFocused,
                    font: .preferredFont(forTextStyle: .body),
                    textColor: .label,
                    submitOnReturn: true
                )

                if newTitleFocused || newMemoFocused {
                    GrowingTextView(
                        text: $newMemo,
                        isFocused: $newMemoFocused,
                        placeholder: "메모 추가",
                        font: .preferredFont(forTextStyle: .callout),
                        textColor: .secondaryLabel,
                        submitOnReturn: true
                    )
                }
            }

            if newTitleFocused || newMemoFocused {
                Spacer()
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
    }

    /// 완료 동그라미 — 양방향 토글 대응. pending이면 토글 후 상태를, 아니면 현재 상태를 표시한다.
    /// 완료 상태는 `largecircle.fill.circle`(외곽 원 + 안 작은 점) + 리스트 색,
    /// 미완료는 빈 `circle` + secondary 회색 — 미리알림 앱과 동일.
    private func completionIcon(for reminder: Reminder) -> some View {
        let pending = pendingCompletionIDs.contains(reminder.id)
        let showCompleted = pending ? !reminder.isCompleted : reminder.isCompleted
        let tint: Color = showCompleted ? (listColor ?? .accentColor) : .secondary
        return Image(systemName: showCompleted ? "largecircle.fill.circle" : "circle")
            .foregroundStyle(tint)
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
    /// **race 차단 시퀀스** (사용자: 편집 중 다른 row 탭):
    /// 1) focus만 먼저 내려 UITextView가 first responder를 양보 → 한 turn 양보
    /// 2) 기존 편집의 update fetch까지 await으로 완전히 마치고 → ForEach diff 정리 대기
    /// 3) 새 editingReminderID 설정 — 그 다음 render에서 새 row가 editing UI로 전환
    /// 단계 사이를 분리하지 않으면 SwiftUI render 한 번 안에서 두 row의 view tree가 동시
    /// swap되어 first responder가 deleted cell에 갇히는 UICollectionView assertion으로 죽는다.
    ///
    /// **알려진 trade-off** — focus를 한 번 떨궜다 다시 잡기 때문에 키보드가 잠깐 내려갔다
    /// 올라온다. 같은 binding을 공유한 채 view swap만 하면 SwiftUI가 binding 변화를 못 알아
    /// 채 새 UITextView가 `becomeFirstResponder`를 받지 못 한다(시도해봤음 — focus 안 들어감).
    /// 키보드 유지를 진짜로 보장하려면 row별 별도 focus binding으로 큰 refactor 필요.
    private func startInlineEdit(_ reminder: Reminder) {
        if editingReminderID == reminder.id { return }

        Task { @MainActor in
            // (1) focus 해제 — view swap 없이 UITextView만 양보.
            if editTitleFocused || editMemoFocused {
                editTitleFocused = false
                editMemoFocused = false
                try? await Task.sleep(for: .milliseconds(80))
            }
            // (2) 기존 편집 commit(=update fetch까지 await) + dispose 완료 대기.
            if editingReminderID != nil {
                await flushInlineEditAwaiting()
                try? await Task.sleep(for: .milliseconds(120))
            }
            // (3) 새 edit 시작.
            editingReminderID = reminder.id
            editingTitle = reminder.title
            editingMemo = reminder.notes ?? ""
            editTitleFocused = true
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
    private func submitNewReminder() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let memo = newMemo
        clearNewRow()
        Task { await viewModel.add(title: trimmed, notes: memo) }
    }

    /// 세부사항 시트(생성) 완료 — Draft를 풀어 add 호출하고 입력 행을 비운다.
    private func saveNewReminder(draft: ReminderDetailSheet.Draft) {
        let trimmed = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let memo = draft.memo
        clearNewRow()
        Task {
            await viewModel.add(
                title: trimmed, notes: memo,
                dueDate: draft.dueDate, includesTime: draft.includesTime
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

