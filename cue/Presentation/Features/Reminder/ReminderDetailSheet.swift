//
//  ReminderDetailSheet.swift
//  cue / Presentation
//

import SwiftUI

/// 미리 알림 세부사항 시트 — iOS "미리 알림" 세부사항 화면을 따른다. 일정 상세 시트
/// (EventDetailSheet)와 같은 툴바·모양으로 맞춘다.
///
/// 모드:
/// - **생성**(`init(title:memo:…onComplete:)`) — 곧장 편집 모드. ✓면 `Draft`를 넘기고 닫힌다.
/// - **기존 항목**(`init(reminder:…)`) — `startsInViewMode`면 **보기 모드**(ReminderReadView)로
///   열리고 연필로 **편집 모드**(ReminderEditForm)에 들어간다. 편집 X는 보기로 돌아가고(변경 있으면
///   폐기 확인), ✓는 `ReminderChanges`를 넘기고 닫는다. 아니면 편집 모드로 열려 X가 곧 닫기다.
///
/// 편집 상태·저장 값 변환은 `ReminderEditDraft`가 갖는다 — 손대지 않은 필드는 원래 값 그대로.
struct ReminderDetailSheet: View {
    /// 생성 완료 시 호출자에게 전달되는 편집 결과.
    struct Draft {
        var title: String
        var memo: String
        var dueDate: Date?
        var includesTime: Bool
        /// 반복 규칙 — 날짜가 켜져 있고 반복을 골랐을 때만 non-nil.
        var recurrence: RecurrenceRule?
    }

    /// 대상 항목(nil이면 생성) — 열 때 한 번 고정한다. 저장 값은 이 값 대비 바뀐 것만 쓰므로,
    /// 저장·완료 직후 부모가 새 값으로 다시 그려도 기준이 흔들리지 않게 상태로 둔다.
    @State private var reminder: Reminder?
    private let lists: [ReminderList]
    private let startsInViewMode: Bool
    private let onComplete: ((Draft) -> Void)?
    private let onSave: ((ReminderChanges) -> Void)?
    private let onToggleCompletion: (() -> Void)?
    private let onDelete: (() -> Void)?

    /// 편집 X로 돌아갈 때의 복원값이자 생성 경로의 변경 감지 기준(기존 항목은 `reminder`
    /// 대비 저장 값으로 판정). 상태로 고정 — 부모가 다시 그려 init이 재실행돼도 그대로.
    @State private var initialDraft: ReminderEditDraft
    @State private var draft: ReminderEditDraft
    @State private var isEditing: Bool
    /// 완료 원의 낙관적 상태 — 탭 즉시 뒤집고 저장은 호출자에게 맡긴다.
    @State private var isCompleted: Bool
    @State private var showingDiscardConfirmation = false
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    /// DatePicker·서브타이틀의 오전/오후·요일을 기기 로케일로 일관되게 표시한다.
    private let deviceLocale = Locale.autoupdatingCurrent

    /// 생성 — 초기값(할일 탭 입력 행의 제목·메모 등)을 받아 편집 모드로 연다.
    init(
        title: String = "",
        memo: String = "",
        dueDate: Date? = nil,
        includesTime: Bool = false,
        recurrence: RecurrenceRule? = nil,
        onComplete: @escaping (Draft) -> Void
    ) {
        let initial = ReminderEditDraft(
            title: title, notes: memo,
            dueDate: dueDate, includesTime: includesTime, recurrence: recurrence
        )
        _reminder = State(initialValue: nil)
        self.lists = []
        self.startsInViewMode = false
        self.onComplete = onComplete
        self.onSave = nil
        self.onToggleCompletion = nil
        self.onDelete = nil
        _initialDraft = State(initialValue: initial)
        _draft = State(initialValue: initial)
        _isEditing = State(initialValue: true)
        _isCompleted = State(initialValue: false)
    }

    /// 기존 항목 — 일정 탭은 보기 모드로(`startsInViewMode: true`), 할일 탭 ⓘ는 편집 모드로 연다.
    init(
        reminder: Reminder,
        lists: [ReminderList],
        startsInViewMode: Bool,
        onSave: @escaping (ReminderChanges) -> Void,
        onToggleCompletion: (() -> Void)? = nil,   // nil → no completion toggle
        onDelete: (() -> Void)? = nil              // nil → no delete button
    ) {
        let initial = ReminderEditDraft(reminder: reminder)
        _reminder = State(initialValue: reminder)
        self.lists = lists
        self.startsInViewMode = startsInViewMode
        self.onComplete = nil
        self.onSave = onSave
        self.onToggleCompletion = onToggleCompletion
        self.onDelete = onDelete
        _initialDraft = State(initialValue: initial)
        _draft = State(initialValue: initial)
        _isEditing = State(initialValue: !startsInViewMode)
        _isCompleted = State(initialValue: reminder.isCompleted)
    }

    var body: some View {
        NavigationStack {
            Form {
                if isEditing {
                    ReminderEditForm(draft: $draft, lists: lists, showsAttributes: reminder != nil)
                } else if let reminder {
                    ReminderReadView(
                        reminder: reminder,
                        lists: lists,
                        isCompleted: isCompleted,
                        onToggleCompletion: completionAction
                    )
                }
                if onDelete != nil {
                    deleteSection
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    closeButton
                }
                if isEditing {
                    ToolbarItem(placement: .confirmationAction) {
                        saveButton
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation { isEditing = true }
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .accessibilityLabel("Edit")
                    }
                }
            }
            .keyboardDismissToolbar()
            .environment(\.locale, deviceLocale)
        }
    }

    // MARK: - 상태

    /// 저장하면 무언가 바뀌는지 — X의 폐기 확인 여부.
    private var hasChanges: Bool {
        if let reminder { return draft.hasChanges(base: reminder) }
        return draft != initialDraft
    }

    private var navigationTitle: LocalizedStringKey {
        isEditing ? "Details" : ""
    }

    /// 완료 원 탭 — 낙관적으로 먼저 뒤집고 저장은 호출자에게. nil이면 원을 그리지 않는다.
    private var completionAction: (() -> Void)? {
        guard let onToggleCompletion else { return nil }
        return {
            isCompleted.toggle()
            onToggleCompletion()
        }
    }

    // MARK: - 툴바

    /// X — 보기 모드는 닫기. 편집 모드는 변경 있으면 폐기 확인 후 보기로(보기로 열지 않았으면 닫기).
    private var closeButton: some View {
        Button {
            if isEditing, hasChanges {
                showingDiscardConfirmation = true
            } else {
                leaveEditing()
            }
        } label: {
            Image(systemName: "xmark")
        }
        .accessibilityLabel("Close")
        // X 버튼을 anchor 삼는 popover. iPhone(compact width)에선 기본이 sheet라
        // presentationCompactAdaptation(.popover)로 popover 강제.
        .popover(isPresented: $showingDiscardConfirmation) {
            discardPopover
                .presentationCompactAdaptation(.popover)
        }
    }

    /// ✓ — 앱 tint가 `.primary`(RootView)라 prominent 캡슐이 검정/흰색이 되므로 글리프는
    /// systemBackground로 칠해 대비를 맞춘다.
    private var saveButton: some View {
        Button {
            save()
        } label: {
            Label("Save", systemImage: "checkmark")
                .labelStyle(.iconOnly)
                .foregroundStyle(Color(.systemBackground))
        }
        .buttonStyle(.glassProminent)
        .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    /// X 버튼 popover — EventDetailSheet와 동일 관용구. 외부 탭으로 dismiss(=취소).
    private var discardPopover: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Discard Changes?")
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Button(role: .destructive) {
                showingDiscardConfirmation = false
                leaveEditing()
            } label: {
                // 회색 system fill capsule + 빨간 destructive 텍스트 — iOS native alert와 동일.
                Text("Discard Changes")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.lg)
        // iPhone popover는 content ideal size를 작게 잡아 minWidth로 명시적 강제 — 화면 ~60% 정도.
        .frame(minWidth: 240)
    }

    // MARK: - 삭제

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Text("Delete Reminder")
                    .frame(maxWidth: .infinity)
            }
            // 다이얼로그는 **여는 버튼에** 붙인다(EventDetailSheet와 같은 이유 — 앵커 위치).
            // 할일엔 회차 범위(EKSpan)가 없어 반복 항목도 통째로 지운다 — 확인만 받는다.
            .confirmationDialog("Delete Reminder", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete Reminder", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            }
        }
    }

    // MARK: - 액션

    /// 편집 종료 — 보기 모드로 열린 기존 항목이면 편집분을 버리고 보기로, 아니면 시트를 닫는다.
    private func leaveEditing() {
        guard isEditing, reminder != nil, startsInViewMode else {
            dismiss()
            return
        }
        draft = initialDraft
        withAnimation { isEditing = false }
    }

    private func save() {
        if let reminder {
            onSave?(draft.changes(base: reminder))
        } else {
            onComplete?(Draft(
                title: draft.title,
                memo: draft.notes,
                dueDate: draft.effectiveDueDate,
                includesTime: draft.effectiveIncludesTime,
                recurrence: draft.effectiveRecurrence
            ))
        }
        dismiss()
    }
}

#Preview {
    ReminderDetailSheet(title: "장보기", memo: "") { _ in }
}
