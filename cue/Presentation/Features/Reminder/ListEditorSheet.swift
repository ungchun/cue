//
//  ListEditorSheet.swift
//  cue / Presentation
//

import SwiftUI

/// 미리알림 리스트 만들기/수정 시트 — iOS Reminders의 "새로운 목록" 시트와 같은 형태.
///
/// **현재 단계**: 제목 + 12색 팔레트만. 아이콘/이모지 팔레트와 "목록 유형/템플릿" 칩은 추후 사이클.
///
/// **`Mode`로 분기** — `.new`는 빈 폼·기본 색, `.edit(list)`는 기존 값을 초기값으로.
/// 저장은 콜백으로 위임해 호출자가 `addList` / `updateList`를 결정한다.
struct ListEditorSheet: View {
    enum Mode {
        case new
        case edit(ReminderList)
    }

    let mode: Mode
    /// 저장 콜백 — `(제목, hex)`. 시트는 검증·trim까지만 하고 실제 저장은 호출자가.
    let onSave: (_ title: String, _ colorHex: String?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    /// 팔레트에서 사용자가 선택한 옵션 id — nil이면 어떤 팔레트도 선택되지 않은 상태.
    /// 편집 모드에서 EventKit hex가 팔레트와 정확히 매칭되지 않으면 nil로 시작해 그리드에 ring 없음.
    @State private var selectedPaletteID: String?
    /// 팔레트 매칭 실패 시 EventKit이 준 원본 hex — identity card 표시·저장에 사용.
    /// 사용자가 팔레트를 새로 고르면 nil이 되고 그때부턴 selectedPaletteID가 source of truth.
    @State private var customHex: String?
    @State private var showingDiscardConfirmation = false
    /// 새 목록 시트가 열리면 곧장 입력할 수 있도록 자동 포커스. 편집 모드엔 자동 포커스 안 함.
    @FocusState private var nameFocused: Bool

    private let initialTitle: String
    private let initialPaletteID: String?
    private let initialCustomHex: String?

    init(mode: Mode, onSave: @escaping (String, String?) -> Void) {
        self.mode = mode
        self.onSave = onSave

        let title: String
        let paletteID: String?
        let customHex: String?
        switch mode {
        case .new:
            title = ""
            paletteID = ListPalette.defaultID
            customHex = nil
        case .edit(let list):
            title = list.title
            if let option = ListPalette.option(forHex: list.colorHex) {
                paletteID = option.id
                customHex = nil
            } else {
                // 팔레트에 정확 일치 없음 — 그리드 ring은 표시 안 하고 원본 hex만 보유.
                paletteID = nil
                customHex = list.colorHex
            }
        }
        self._title = State(initialValue: title)
        self._selectedPaletteID = State(initialValue: paletteID)
        self._customHex = State(initialValue: customHex)
        self.initialTitle = title
        self.initialPaletteID = paletteID
        self.initialCustomHex = customHex
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { identityCard }
                Section { paletteGrid }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .keyboardDismissToolbar()
            .task {
                // Form/SwiftUI 레이아웃이 잡힌 후 포커스가 안정적으로 들어가도록 약간 미룬다.
                if case .new = mode {
                    try? await Task.sleep(for: .milliseconds(120))
                    nameFocused = true
                }
            }
        }
    }

    /// 모드별 navigation title. 새 목록 / 목록 정보.
    private var navigationTitle: String {
        switch mode {
        case .new: "새로운 목록"
        case .edit: "목록 정보"
        }
    }

    /// 큰 원형 아이콘 + 가운데 정렬 제목 TextField. 색은 선택된 팔레트.
    /// 크기 — 원 80pt, 내부 SF Symbol 44pt(semibold), TextField는 titleMedium(20pt).
    private var identityCard: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(displayColor)
                    .frame(width: 80, height: 80)
                Image(systemName: "list.bullet")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)

            TextField("목록 이름", text: $title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(displayColor)
                .focused($nameFocused)
                .submitLabel(.done)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.vertical, Spacing.sm)
    }

    /// 12색 2×6 그리드. 선택된 색은 외곽 ring으로 강조.
    private var paletteGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.md), count: 6),
            spacing: Spacing.md
        ) {
            ForEach(ListPalette.palette) { option in
                Button {
                    selectedPaletteID = option.id
                    // 팔레트를 새로 골랐으니 원본 custom hex는 더 이상 source of truth가 아님.
                    customHex = nil
                } label: {
                    Circle()
                        .fill(option.displayColor)
                        .frame(width: 36, height: 36)
                        .overlay {
                            // 선택된 색만 회색 ring으로 둘러싼다(iOS Reminders와 동일).
                            if option.id == selectedPaletteID {
                                Circle()
                                    .stroke(Color.secondary.opacity(0.5), lineWidth: 3)
                                    .frame(width: 46, height: 46)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            // 변경이 있으면 폐기 confirm, 없으면 바로 dismiss — ReminderDetailSheet와 같은 패턴.
            Button {
                if hasChanges {
                    showingDiscardConfirmation = true
                } else {
                    dismiss()
                }
            } label: {
                Label("닫기", systemImage: "xmark")
                    .labelStyle(.iconOnly)
            }
            .popover(isPresented: $showingDiscardConfirmation) {
                discardPopover
                    .presentationCompactAdaptation(.popover)
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button {
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                // 팔레트 선택이 있으면 그 hex, 아니면 EventKit 원본 hex 그대로 유지.
                onSave(trimmed, selectedPalette?.hex ?? customHex)
                dismiss()
            } label: {
                Label("저장", systemImage: "checkmark")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.white)
            }
            .buttonStyle(.glassProminent)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var discardPopover: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("이 변경 사항을 폐기\n하겠습니까?")
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Button(role: .destructive) {
                showingDiscardConfirmation = false
                dismiss()
            } label: {
                Text("변경 사항 폐기")
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

    private var hasChanges: Bool {
        title != initialTitle
            || selectedPaletteID != initialPaletteID
            || customHex != initialCustomHex
    }

    /// 현재 선택된 팔레트(있으면). 없으면 nil — 그리드 ring 표시 분기와 저장 hex fallback에 쓰인다.
    private var selectedPalette: ListPalette? {
        guard let selectedPaletteID else { return nil }
        return ListPalette.palette.first { $0.id == selectedPaletteID }
    }

    /// identity card(큰 동그라미·이름)의 표시 색. 팔레트 선택이 있으면 그 색,
    /// 없으면 customHex로 만든 Color, 둘 다 없으면 secondary로 fallback.
    private var displayColor: Color {
        if let palette = selectedPalette { return palette.displayColor }
        if let hex = customHex, let color = Color(hex: hex) { return color }
        return .secondary
    }
}

/// iOS Reminders 12색 팔레트. 시스템 컬러 매핑이 있으면 system color, 없으면 sRGB raw.
/// `hex`는 EventKit 저장용, `displayColor`는 SwiftUI 그리기용. 둘은 일치하지 않아도 무방
/// (저장은 hex, 다음 fetch에서 hex → Color로 재구성된다).
private struct ListPalette: Identifiable, Hashable {
    let id: String
    let hex: String
    let displayColor: Color

    static let palette: [ListPalette] = [
        .init(id: "red",    hex: "#FF3B30", displayColor: Color(uiColor: .systemRed)),
        .init(id: "orange", hex: "#FF9500", displayColor: Color(uiColor: .systemOrange)),
        .init(id: "yellow", hex: "#FFCC00", displayColor: Color(uiColor: .systemYellow)),
        .init(id: "green",  hex: "#34C759", displayColor: Color(uiColor: .systemGreen)),
        .init(id: "sky",    hex: "#5AC8FA", displayColor: Color(uiColor: .systemTeal)),
        .init(id: "blue",   hex: "#007AFF", displayColor: Color(uiColor: .systemBlue)),
        .init(id: "indigo", hex: "#5856D6", displayColor: Color(uiColor: .systemIndigo)),
        .init(id: "pink",   hex: "#FF2D55", displayColor: Color(uiColor: .systemPink)),
        .init(id: "purple", hex: "#AF52DE", displayColor: Color(uiColor: .systemPurple)),
        .init(id: "brown",  hex: "#A2845E", displayColor: Color(uiColor: .systemBrown)),
        .init(id: "gray",   hex: "#8E8E93", displayColor: Color(uiColor: .systemGray)),
        // 12번째는 시스템 색 매핑이 없어 raw hex로 정의(iOS Reminders의 연분홍과 가까움).
        .init(id: "rose",   hex: "#F2B6A8", displayColor: Color(hex: "#F2B6A8") ?? .pink),
    ]

    static let defaultID = "blue"
    static let `default` = palette.first { $0.id == defaultID }!

    /// 기존 리스트의 colorHex로 팔레트 옵션을 역추적. 정확 일치하는 hex가 없으면 nil
    /// (호출자가 default로 fallback) — 사용자 임의 hex여도 시트가 깨지지 않게.
    static func option(forHex hex: String?) -> ListPalette? {
        guard let hex else { return nil }
        return palette.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }
    }
}

#Preview("New") {
    ListEditorSheet(mode: .new) { _, _ in }
}

#Preview("Edit") {
    ListEditorSheet(
        mode: .edit(ReminderList(id: "L1", title: "회사", colorHex: "#FF9500"))
    ) { _, _ in }
}
