//
//  YearMonthWheelPicker.swift
//  cue / Presentation
//

import SwiftUI
import UIKit

/// 연·월 두 휠만 있는 날짜 피커.
///
/// SwiftUI `DatePicker`는 일(day) 휠을 뺄 수 없어 `UIDatePicker`의 `.yearAndMonth` 모드를 감싼다.
struct YearMonthWheelPicker: UIViewRepresentable {
    @Binding var selection: Date
    /// 고를 수 있는 달 범위 — 페이저가 넘길 수 있는 범위와 같아야 점프한 달이 잘리지 않는다.
    let range: ClosedRange<Date>

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .yearAndMonth
        picker.preferredDatePickerStyle = .wheels
        // 월 이름·연 표기와 달 경계를 앱 다른 화면(월 제목·격자)과 같은 기준으로.
        picker.calendar = .current
        picker.locale = .current
        picker.minimumDate = range.lowerBound
        picker.maximumDate = range.upperBound
        picker.date = selection
        picker.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        return picker
    }

    /// 휠 고유 크기를 그대로 쓴다 — 담는 쪽(팝오버)이 이 크기에 맞춰 줄어 위아래 빈 공간이 생기지 않게.
    /// 폭은 제안이 있으면 따르고, 없으면(팝오버가 이상 크기를 물을 때) 휠 고유 폭.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIDatePicker, context: Context) -> CGSize? {
        let natural = uiView.sizeThatFits(.zero)
        return CGSize(width: proposal.width ?? natural.width, height: natural.height)
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        // 바인딩이 새로 만들어져도 최신 것에 써 넣도록.
        context.coordinator.selection = $selection
        picker.minimumDate = range.lowerBound
        picker.maximumDate = range.upperBound
        // 같은 값으로 다시 setDate하면 사용자가 굴리던 휠이 튀므로, 바깥에서 바뀐 경우(Today)만.
        if picker.date != selection {
            picker.setDate(selection, animated: true)
        }
    }

    /// 휠 변경을 바인딩으로 올린다 — UIKit target-action은 NSObject 대상이 필요하다.
    @MainActor
    final class Coordinator: NSObject {
        var selection: Binding<Date>

        init(selection: Binding<Date>) {
            self.selection = selection
        }

        @objc func valueChanged(_ sender: UIDatePicker) {
            selection.wrappedValue = sender.date
        }
    }
}
