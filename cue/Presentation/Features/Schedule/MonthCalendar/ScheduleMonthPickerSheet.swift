//
//  ScheduleMonthPickerSheet.swift
//  cue / Presentation
//

import SwiftUI

/// 월 제목을 눌러 여는 연·월 점프 카드 — 제목에서 뻗어 나오는 팝오버로 띄운다.
///
/// 휠을 돌리는 것만으로는 이동하지 않고 확인을 눌러야 그 달로 간다 — 휠을 굴리는 중간 달마다
/// 페이저가 따라 넘어가 조회가 몰리지 않게. 바깥을 눌러 닫으면 아무 데도 가지 않는다.
struct ScheduleMonthPickerSheet: View {
    let viewModel: ScheduleMonthViewModel

    @Environment(\.dismiss) private var dismiss
    /// 휠이 가리키는 달 — 확인 전까지는 VM에 반영하지 않는 임시 값.
    @State private var draft: Date

    init(viewModel: ScheduleMonthViewModel) {
        self.viewModel = viewModel
        _draft = State(initialValue: viewModel.visibleMonthStart)
    }

    var body: some View {
        // 내비게이션 바 없이 버튼 행 + 휠만 — 카드가 내용 높이에 딱 맞아 위아래 빈 공간이 없다.
        VStack(spacing: Spacing.sm) {
            HStack {
                // 휠만 이번 달로 돌린다 — 이동은 여전히 확인이 정한다.
                Button("Today") { draft = Date() }
                    .buttonStyle(.glass)
                Spacer()
                // 체크마크 확인 버튼 — 카탈로그 "Done"의 ko가 「닫기」라, 바깥 눌러 닫기(이동 없음)와
                // 같은 말로 읽히지 않게 "OK"(확인)를 접근성 라벨로만 쓴다.
                Button(role: .confirm) {
                    viewModel.jump(to: draft)
                    dismiss()
                } label: {
                    // 앱 tint가 .primary라 채움이 다크=흰색·라이트=검정 — 기본 흰 글리프는 다크에서 묻힌다.
                    // 저장 버튼(EventDetailSheet)과 같이 배경색으로 칠해 두 모드 모두 반전 대비를 낸다.
                    Label("OK", systemImage: "checkmark")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Color(.systemBackground))
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
            }
            YearMonthWheelPicker(selection: $draft, range: viewModel.monthRange)
        }
        .padding(Spacing.md)
        // iPhone에서도 시트로 바뀌지 않고 떠 있는 카드로 — 제목 바로 아래에서 짧게 고르고 닫는 흐름.
        .presentationCompactAdaptation(.popover)
    }
}
