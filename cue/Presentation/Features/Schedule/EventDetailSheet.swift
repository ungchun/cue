//
//  EventDetailSheet.swift
//  cue / Presentation
//

import EventKit
import SwiftUI

/// 자체 이벤트 상세 시트 — Apple 캘린더의 이벤트 보기/편집/신규 시트를 SwiftUI로 재구성한다.
///
/// `EKEventEditViewController`를 쓰지 않는 이유: iOS 17부터 그 화면은 별도 시스템
/// 프로세스(OOP 원격 뷰)로 렌더돼 폼 위 터치가 우리 앱에 오지 않고, 그래서 시트를
/// 아래로 끌어 닫는 제스처가 서드파티 앱에선 동작하지 않는다(실기기 로그로 확정).
/// 자체 폼이면 일반 SwiftUI 시트라 스와이프 닫기·디자인 통일·즉시 표시가 전부 해결된다.
///
/// 모드: 기존 이벤트는 **보기 모드**(EventReadView)로 열리고 연필로 **편집 모드**
/// (EventEditForm)에 들어간다. 편집 X는 보기로 돌아가고(변경 있으면 폐기 확인), ✓는 저장 후
/// 시트를 닫는다. 신규 이벤트는 곧장 편집 모드. 수정 불가 캘린더(공휴일·구독)는 보기 전용.
///
/// 반복 이벤트는 탭한 **회차**를 연다(EventOccurrenceLocator) — 저장·삭제는 Apple과 동일하게
/// "이 이벤트에만 / 이후 모든 이벤트에"를 묻는다. 결과는 `onCompletion`(EventEditOutcome).
struct EventDetailSheet: View {
    let eventStore: EKEventStore
    let onCompletion: (EventEditOutcome) -> Void

    /// 대상 회차 — 열 때 한 번만 찾는다. 상태로 고정하는 이유: 저장·삭제 직후 부모가 다시
    /// 그려지며 init이 재실행돼도 (이미 지워진) 이벤트를 다시 찾다 신규 모드로 뒤집히지 않게.
    @State private var event: EKEvent?
    /// 변경 감지·보기 모드 표시용 스냅샷 — 편집 X로 돌아갈 때 draft를 이 값으로 되돌린다.
    @State private var initialDraft: EventEditDraft
    @State private var draft: EventEditDraft
    @State private var isEditing: Bool
    @State private var showingDiscardConfirmation = false
    @State private var showingSaveSpanDialog = false
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    /// 쓰기 가능한 캘린더 목록 — 캘린더 선택 행.
    private let calendars: [EKCalendar]

    /// `occurrence`가 nil이면 신규 모드(편집 모드로 시작).
    init(eventStore: EKEventStore, occurrence: EventOccurrenceRef? = nil, onCompletion: @escaping (EventEditOutcome) -> Void) {
        self.eventStore = eventStore
        self.onCompletion = onCompletion

        let event = occurrence.flatMap { EventOccurrenceLocator.locate($0, in: eventStore) }
        var initial = event.map(EventEditDraft.init(event:)) ?? .newEvent(now: .now)
        if initial.calendarID == nil {
            initial.calendarID = eventStore.defaultCalendarForNewEvents?.calendarIdentifier
        }
        _event = State(initialValue: event)
        _initialDraft = State(initialValue: initial)
        _draft = State(initialValue: initial)
        _isEditing = State(initialValue: event == nil)
        self.calendars = eventStore.calendars(for: .event).filter(\.allowsContentModifications)
    }

    var body: some View {
        NavigationStack {
            Form {
                if isEditing {
                    EventEditForm(draft: $draft, calendars: calendars)
                } else if let event {
                    EventReadView(event: event, draft: initialDraft)
                }
                if canModify {
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
                } else if canModify {
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
            .alert("Error", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - 상태

    /// 기존 이벤트이고 캘린더가 수정을 허용할 때만 편집·삭제 가능.
    private var canModify: Bool {
        event?.calendar?.allowsContentModifications == true
    }

    private var navigationTitle: LocalizedStringKey {
        guard isEditing else { return "" }
        return event == nil ? "New Event" : "Edit Event"
    }

    // MARK: - 툴바

    /// X — 보기 모드는 닫기. 편집 모드는 변경 있으면 폐기 확인 후 보기로(신규면 닫기).
    private var closeButton: some View {
        Button {
            if isEditing, draft != initialDraft {
                showingDiscardConfirmation = true
            } else {
                leaveEditing()
            }
        } label: {
            Image(systemName: "xmark")
        }
        .accessibilityLabel("Close")
        .popover(isPresented: $showingDiscardConfirmation) {
            discardPopover
                .presentationCompactAdaptation(.popover)
        }
    }

    /// ✓ — 앱 tint가 `.primary`(RootView)라 prominent 캡슐이 검정/흰색이 되므로 글리프는
    /// systemBackground로 칠해 대비를 맞춘다.
    private var saveButton: some View {
        Button {
            saveTapped()
        } label: {
            Label("Save", systemImage: "checkmark")
                .labelStyle(.iconOnly)
                .foregroundStyle(Color(.systemBackground))
        }
        .buttonStyle(.glassProminent)
        .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        // 반복 이벤트 저장 범위 — Apple 캘린더와 동일한 질문. 여는 버튼(저장)에
        // 붙여야 그 위에 앵커된다(삭제 다이얼로그와 같은 이유).
        .confirmationDialog("This is a repeating event.", isPresented: $showingSaveSpanDialog, titleVisibility: .visible) {
            Button("Save for This Event Only") { save(span: .thisEvent) }
            Button("Save for Future Events") { save(span: .futureEvents) }
        }
    }

    /// X 버튼 popover — ReminderDetailSheet와 동일 관용구.
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
        .frame(minWidth: 240)
    }

    // MARK: - 삭제

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Text("Delete Event")
                    .frame(maxWidth: .infinity)
            }
            // 다이얼로그는 **여는 버튼에** 붙인다 — 루트(Form)에 붙이면 앵커가
            // 버튼과 무관한 자리라 확인 창이 화면 중간에 동떠 보인다(실기기).
            // 삭제 — 반복이면 범위까지 묻는다.
            .confirmationDialog("Delete Event", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                if event?.hasRecurrenceRules == true {
                    Button("Delete This Event Only", role: .destructive) { delete(span: .thisEvent) }
                    Button("Delete All Future Events", role: .destructive) { delete(span: .futureEvents) }
                } else {
                    Button("Delete Event", role: .destructive) { delete(span: .thisEvent) }
                }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    // MARK: - 액션

    /// 편집 종료 — 신규면 시트를 닫고, 기존이면 편집분을 버리고 보기 모드로.
    private func leaveEditing() {
        guard isEditing, event != nil else {
            cancel()
            return
        }
        draft = initialDraft
        withAnimation { isEditing = false }
    }

    private func saveTapped() {
        // 반복 시리즈의 일부면 저장 범위를 먼저 묻는다 — 그 전엔 이벤트를 안 건드린다.
        if event?.hasRecurrenceRules == true {
            showingSaveSpanDialog = true
        } else {
            save(span: .thisEvent)
        }
    }

    private func save(span: EKSpan) {
        let target = event ?? EKEvent(eventStore: eventStore)
        // 캘린더를 먼저 정해야 그 캘린더가 지원하는 "다음으로 표시"인지 판정할 수 있다.
        target.calendar = calendars.first { $0.calendarIdentifier == draft.calendarID }
            ?? target.calendar
            ?? eventStore.defaultCalendarForNewEvents
        var final = draft
        let mask = target.calendar?.supportedEventAvailabilities ?? []
        if !EventEditDraft.availabilityOptions(for: mask).contains(final.availability) {
            final.availability = .notSupported   // 지원 밖 값은 쓰지 않고 EventKit 값을 유지
        }
        final.apply(to: target)
        do {
            try eventStore.save(target, span: span, commit: true)
            onCompletion(.saved)
            dismiss()
        } catch {
            eventStore.reset()   // 실패 시 캐시에 남은 미커밋 변경을 원복
            errorMessage = String(localized: "Couldn't save the event.")
        }
    }

    private func delete(span: EKSpan) {
        guard let event else { return }
        do {
            try eventStore.remove(event, span: span, commit: true)
            onCompletion(.deleted)
            dismiss()
        } catch {
            errorMessage = String(localized: "Couldn't delete the event.")
        }
    }

    private func cancel() {
        onCompletion(.canceled)
        dismiss()
    }
}
