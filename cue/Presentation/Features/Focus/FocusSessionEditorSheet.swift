//
//  FocusSessionEditorSheet.swift
//  cue / Presentation
//

import SwiftUI

/// 세션 1건을 새로 만들거나 기존 항목을 수정하는 풀 시트.
/// `FocusSessionsListSheet` 위에 스택으로 떠 — 부모 목록 시트는 닫히지 않고 그 위에 올라온다.
struct FocusSessionEditorSheet: View {
    /// 모드 — `.create`면 빈 폼, `.edit(session)`이면 그 세션의 값으로 prefill.
    enum Mode: Equatable {
        case create
        case edit(FocusSession)
    }

    let mode: Mode
    @Bindable var viewModel: FocusViewModel

    @Environment(\.dismiss) private var dismiss

    /// 폼 입력값 — 시트가 떠 있는 동안 임시로 들고 있다가 저장 시 ViewModel에 반영.
    @State private var title: String = ""
    @State private var settings: FocusSettings = .default
    /// 사용자가 고른 색의 hex. 프리셋 탭 또는 ColorPicker로 갱신된다.
    @State private var colorHex: String = Self.defaultColorHex

    /// 어느 입력 필드가 포커스인지 추적. numberPad엔 Return이 없어 keyboard toolbar의
    /// "완료" 버튼이 `nil`로 떨어뜨려 키보드를 닫는다.
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title, focus, rest
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    TextField("세션 이름", text: $title)
                        .focused($focusedField, equals: .title)
                }
                Section("색상") {
                    paletteRow
                }
                Section("시간") {
                    minuteRow(label: "집중 시간", minutes: focusMinutesBinding, field: .focus)
                    if settings.isRepeating {
                        minuteRow(label: "휴식 시간", minutes: restMinutesBinding, field: .rest)
                    }
                }
                Section("반복") {
                    Toggle("반복", isOn: $settings.isRepeating)
                    if settings.isRepeating {
                        Stepper(value: $settings.cycleCount, in: 2...10) {
                            LabeledContent("사이클 수", value: "\(settings.cycleCount)회")
                        }
                    }
                }
                // 수정 모드일 때만 맨 아래 빨강 삭제 — 신규 모드엔 지울 대상이 없다.
                if case .edit(let session) = mode {
                    deleteSection(for: session)
                }
            }
            .navigationTitle(isEditing ? "세션 수정" : "새 세션")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "저장" : "추가") {
                        save()
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
                // numberPad는 Return이 없어 키보드 위 toolbar의 "완료"로 닫는다.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") { focusedField = nil }
                }
            }
        }
        .onAppear {
            // 시트가 처음 뜰 때 한 번 — 편집 모드면 그 세션의 값으로, 생성 모드면 빈 상태로
            // 폼을 초기화한다. 자동 포커스는 두지 않는다 — 시트가 올라오자마자 키보드가
            // 튀어오르면 시간 입력 row가 가려져 사용자가 한 박자 늦게 인지하게 된다.
            if case .edit(let session) = mode {
                title = session.title
                settings = session.settings
                colorHex = session.colorHex
            } else {
                title = ""
                settings = .default
                colorHex = Self.defaultColorHex
            }
        }
    }

    // MARK: - 색상 섹션

    /// 프리셋 색 팔레트 — adaptive grid로 폭에 맞춰 자동 줄바꿈.
    private var paletteRow: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: Spacing.xxl), spacing: Spacing.md)],
            spacing: Spacing.md
        ) {
            ForEach(Self.palette, id: \.hex) { preset in
                colorSwatch(preset)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    /// 단일 프리셋 스와치 — 탭하면 그 hex를 선택, 선택된 항목엔 흰색 체크마크 overlay.
    private func colorSwatch(_ preset: ColorPreset) -> some View {
        let isSelected = colorHex.lowercased() == preset.hex.lowercased()
        return Circle()
            .fill(preset.displayColor)
            .frame(width: Spacing.xl, height: Spacing.xl)
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Circle())
            .onTapGesture {
                colorHex = preset.hex
            }
            .accessibilityLabel(preset.name)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - 삭제 섹션 (수정 모드 전용)

    /// 빨강 destructive 버튼이 든 단독 섹션 — 폼 맨 아래에 배치.
    private func deleteSection(for session: FocusSession) -> some View {
        Section {
            Button(role: .destructive) {
                viewModel.deleteSession(id: session.id)
                dismiss()
            } label: {
                Text("세션 삭제")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 파생값

    /// `.edit`이면 true.
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    /// 좌우 공백 제거된 제목 — 저장 가능 여부 판단·실제 저장에 사용.
    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 도메인의 초 단위 `focusDuration`을 분 단위 `Int`로 노출하는 binding.
    /// setter는 1~59분으로 클램프 — 60 이상을 막아 사용자 요청 범위를 보장한다.
    private var focusMinutesBinding: Binding<Int> {
        Binding(
            get: { Int(settings.focusDuration / 60) },
            set: { settings.focusDuration = TimeInterval(Self.clampMinutes($0) * 60) }
        )
    }

    /// 휴식도 같은 1~59분 범위.
    private var restMinutesBinding: Binding<Int> {
        Binding(
            get: { Int(settings.restDuration / 60) },
            set: { settings.restDuration = TimeInterval(Self.clampMinutes($0) * 60) }
        )
    }

    /// 입력값을 허용 범위로 클램프. 빈 입력(0)이나 음수는 1로, 60 이상은 59로.
    private static func clampMinutes(_ value: Int) -> Int {
        max(1, min(59, value))
    }

    // MARK: - 시간 row builder

    /// "집중 시간 [____] 분 [- +]" 한 줄. TextField로 직접 입력하거나 Stepper -/+로 ±1.
    /// 두 컨트롤이 같은 binding을 공유해 양쪽 어디로 바꿔도 즉시 동기화된다.
    private func minuteRow(label: String, minutes: Binding<Int>, field: Field) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", value: minutes, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: field)
                // "59"(2자리)가 넉넉히 들어가는 폭. xl(32)로는 좁고 xxl(48)이 자연스러움.
                .frame(width: Spacing.xxl)
            Text("분")
                .foregroundStyle(.secondary)
            Stepper("", value: minutes, in: 1...59)
                .labelsHidden()
        }
    }

    // MARK: - 저장

    /// 모드에 따라 추가 또는 수정 호출.
    private func save() {
        let name = trimmedTitle
        guard !name.isEmpty else { return }
        switch mode {
        case .create:
            viewModel.addSession(title: name, settings: settings, colorHex: colorHex)
        case .edit(let session):
            viewModel.updateSession(id: session.id, title: name, settings: settings, colorHex: colorHex)
        }
    }

    // MARK: - 프리셋 정의

    /// 신규 시트가 처음 떴을 때의 기본 색 — 시스템 회색(중성). 사용자가 안 골라도 의미 있는
    /// 폴백을 보장.
    private static let defaultColorHex = "#8E8E93"

    /// 단일 프리셋 — 화면용 SwiftUI Color와 저장용 hex 쌍.
    private struct ColorPreset {
        /// 접근성 라벨 — VoiceOver가 읽는 색 이름.
        let name: String
        /// 팔레트 swatch에 그려질 Color (Apple 시스템 컬러).
        let displayColor: Color
        /// 저장될 hex 문자열. 같은 색의 시스템 RGB 값과 일치시켜 두 표현이 어긋나지 않게 한다.
        let hex: String
    }

    /// 기본 팔레트 — Apple 시스템 컬러 10종(빨/주/노/초/민트/파/인디고/보라/분홍/회색).
    /// hex는 각 시스템 컬러의 라이트 모드 sRGB 값과 일치시켜 행 캡슐·메인 화면이 같은
    /// 톤으로 보이도록 한다.
    private static let palette: [ColorPreset] = [
        ColorPreset(name: "빨강", displayColor: .red, hex: "#FF3B30"),
        ColorPreset(name: "주황", displayColor: .orange, hex: "#FF9500"),
        ColorPreset(name: "노랑", displayColor: .yellow, hex: "#FFCC00"),
        ColorPreset(name: "초록", displayColor: .green, hex: "#34C759"),
        ColorPreset(name: "민트", displayColor: .mint, hex: "#00C7BE"),
        ColorPreset(name: "파랑", displayColor: .blue, hex: "#007AFF"),
        ColorPreset(name: "인디고", displayColor: .indigo, hex: "#5856D6"),
        ColorPreset(name: "보라", displayColor: .purple, hex: "#AF52DE"),
        ColorPreset(name: "분홍", displayColor: .pink, hex: "#FF2D55"),
        ColorPreset(name: "회색", displayColor: .gray, hex: "#8E8E93"),
    ]
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        FocusSessionEditorSheet(
            mode: .create,
            viewModel: FocusViewModel(dependencies: .preview)
        )
        .presentationDetents([.large])
    }
}
