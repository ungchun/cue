//
//  EventEditSheet.swift
//  cue / Presentation
//

import EventKit
import EventKitUI
import SwiftUI

/// iOS 캘린더의 "신규 이벤트" 시트를 그대로 띄우는 SwiftUI 래퍼.
///
/// `EKEventEditViewController`(EventKitUI 제공)는 Apple 캘린더 앱과 동일한 UI를 노출하며
/// 제목·위치·하루 종일·시작/종료·이동 시간·반복·캘린더·초대받은 사람·알림·URL·메모를
/// 모두 처리한다. 우리가 자체 SwiftUI 폼을 짜는 대신 이 컨트롤러를 띄우면 시각적·기능적
/// 100% 동일이 자동 보장된다.
///
/// 컨트롤러는 `.sheet`에 직접 반환한다 — `UINavigationController`로 감싸면 SwiftUI가
/// 시트 컨텐츠를 NavigationStack에 push하려다 충돌한다("Pushing a navigation controller
/// is not supported"). 모달 시트 환경에서 `EKEventEditViewController`는 자체 toolbar를
/// 그린다.
///
/// dismiss는 `controller.dismiss(...)`를 직접 호출하지 않고 `onCompletion`이
/// `showingNewEvent`를 false로 떨어뜨려 SwiftUI가 닫게 한다 — 그래야 시트 상태와
/// SwiftUI binding이 일관된다.
struct EventEditSheet: UIViewControllerRepresentable {
    let onCompletion: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let editor = EKEventEditViewController()
        editor.eventStore = context.coordinator.store
        editor.editViewDelegate = context.coordinator
        // event를 명시 지정하지 않으면 빈 이벤트로 시작 — iOS 캘린더 "신규"와 동일.
        return editor
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {
        // 시트는 한 번 만들어지면 내부 상태는 컨트롤러가 모두 관리한다 — 갱신 불필요.
    }

    @MainActor
    final class Coordinator: NSObject, EKEventEditViewDelegate {
        /// 컨트롤러 생애 동안 유지해야 하는 EKEventStore — 권한·이벤트 객체 그래프를 공유.
        let store = EKEventStore()
        let onCompletion: () -> Void

        init(onCompletion: @escaping () -> Void) {
            self.onCompletion = onCompletion
        }

        /// 저장·취소·삭제 어떤 액션이든 SwiftUI 시트 상태를 false로 떨어뜨려 닫는다.
        /// 저장 액션이면 컨트롤러가 내부적으로 `store`에 save까지 마친 상태로 들어온다.
        func eventEditViewController(
            _ controller: EKEventEditViewController,
            didCompleteWith action: EKEventEditViewAction
        ) {
            onCompletion()
        }
    }
}
