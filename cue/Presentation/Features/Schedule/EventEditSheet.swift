//
//  EventEditSheet.swift
//  cue / Presentation
//

import EventKit
import EventKitUI
import SwiftUI

/// iOS 캘린더의 "신규/편집 이벤트" 시트를 그대로 띄우는 SwiftUI 래퍼.
///
/// `EKEventEditViewController`(EventKitUI 제공)는 Apple 캘린더 앱과 동일한 UI를 노출하며
/// 제목·위치·하루 종일·시작/종료·이동 시간·반복·캘린더·초대받은 사람·알림·URL·메모를
/// 모두 처리한다. 우리가 자체 SwiftUI 폼을 짜는 대신 이 컨트롤러를 띄우면 시각적·기능적
/// 100% 동일이 자동 보장된다.
///
/// `editingEventID`가 nil이면 "신규" 모드(빈 이벤트), 값이 있으면 그 ID로 `eventStore.
/// event(withIdentifier:)`를 조회해 편집 모드로 띄운다 — 헤더가 "이벤트 편집"으로 바뀌고
/// 기존 값들이 채워진 상태로 시작한다.
///
/// 컨트롤러는 `.sheet`에 직접 반환한다 — `UINavigationController`로 감싸면 SwiftUI가
/// 시트 컨텐츠를 NavigationStack에 push하려다 충돌한다("Pushing a navigation controller
/// is not supported"). 모달 시트 환경에서 `EKEventEditViewController`는 자체 toolbar를
/// 그린다.
///
/// `eventStore`는 호출자가 미리 만들어 주입한다 — 컨트롤러 안에서 새 store를 만들면
/// 캘린더 목록·기본 캘린더·권한 캐시를 시트 표시 시점에 처음 조회하게 되어 데이터가
/// 한 박자 늦게 채워지고 LaunchServices/persona 시스템 로그가 무더기로 찍힌다.
/// `ScheduleView`가 화면 진입 시 warm-up한 store를 공유하면 그 비용이 사전 분산된다.
///
/// dismiss는 `controller.dismiss(...)`를 직접 호출하지 않고 `onCompletion`이
/// SwiftUI binding을 false/nil로 떨어뜨려 시트를 닫게 한다 — 그래야 시트 상태와
/// SwiftUI binding이 일관된다.
struct EventEditSheet: UIViewControllerRepresentable {
    let eventStore: EKEventStore
    /// nil이면 신규 모드. 값이 있으면 그 ID의 기존 이벤트를 편집한다.
    let editingEventID: String?
    /// 저장이면 true, 취소·삭제면 false — 호출처가 분석 이벤트(event_created) 판별에 쓴다.
    let onCompletion: (Bool) -> Void

    init(eventStore: EKEventStore, editingEventID: String? = nil, onCompletion: @escaping (Bool) -> Void) {
        self.eventStore = eventStore
        self.editingEventID = editingEventID
        self.onCompletion = onCompletion
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let editor = EKEventEditViewController()
        editor.eventStore = eventStore
        editor.editViewDelegate = context.coordinator
        // editingEventID가 있으면 기존 EKEvent를 찾아 주입 → "이벤트 편집" 모드.
        // 못 찾거나 nil이면 그대로 두어 "신규" 모드(빈 이벤트).
        if let id = editingEventID,
           let existing = eventStore.event(withIdentifier: id) {
            editor.event = existing
        }
        return editor
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {
        // 시트는 한 번 만들어지면 내부 상태는 컨트롤러가 모두 관리한다 — 갱신 불필요.
    }

    @MainActor
    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onCompletion: (Bool) -> Void

        init(onCompletion: @escaping (Bool) -> Void) {
            self.onCompletion = onCompletion
        }

        /// 저장·취소·삭제 어떤 액션이든 SwiftUI 시트 상태를 false로 떨어뜨려 닫는다.
        /// 저장 액션이면 컨트롤러가 내부적으로 `eventStore`에 save까지 마친 상태.
        func eventEditViewController(
            _ controller: EKEventEditViewController,
            didCompleteWith action: EKEventEditViewAction
        ) {
            onCompletion(action == .saved)
        }
    }
}

/// `EventEditSheet`를 시트 콘텐츠로 띄우면서 첫 표시 직후 짧게 가운데 로딩 인디케이터를
/// 덮어둔다. `EKEventEditViewController`는 lazy하게 LaunchServices/usermanagerd/persona
/// 시스템 IPC를 호출하느라 표시 직후 약 0.5~0.8초 정도 콘텐츠가 비어 보이는 구간이 있다 —
/// 이 시간 동안 빈 시트 대신 spinner를 보여줘 사용자가 "응답이 없다"는 인상을 받지 않게 한다.
///
/// IPC가 끝나는 정확한 시점을 알 방법이 없어 시간 기반으로 fade out — 빠른 케이스엔 spinner가
/// 잠깐 보이다 사라지고, 느린 케이스엔 콘텐츠가 그려진 뒤 spinner가 자연스럽게 걷힌다.
struct EventEditSheetContainer: View {
    let eventStore: EKEventStore
    let editingEventID: String?
    let onCompletion: (Bool) -> Void

    @State private var loaderVisible = true

    init(eventStore: EKEventStore, editingEventID: String? = nil, onCompletion: @escaping (Bool) -> Void) {
        self.eventStore = eventStore
        self.editingEventID = editingEventID
        self.onCompletion = onCompletion
    }

    var body: some View {
        ZStack {
            EventEditSheet(
                eventStore: eventStore,
                editingEventID: editingEventID,
                onCompletion: onCompletion
            )
            if loaderVisible {
                Color(.systemBackground)
                    .overlay {
                        ProgressView()
                            .controlSize(.large)
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .task {
            // 700ms — LaunchServices/usermanagerd 첫 IPC가 보통 그 안에 끝난다. 더 빠르면 spinner가
            // 잠깐 보일 뿐, 더 늦으면 spinner 뒤에서 콘텐츠가 이미 준비된 상태로 fade out.
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeOut(duration: 0.2)) {
                loaderVisible = false
            }
        }
    }
}
