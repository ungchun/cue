//
//  LiveActivityAnalyticsBridge.swift
//  cue / Shared
//
//  잠금화면 Live Activity 인텐트(`LiveActivityIntent`)의 perform()은 본앱 프로세스에서
//  실행되지만, 이 파일은 위젯 익스텐션 타깃에도 컴파일되므로 Domain(`AnalyticsEvent`)·
//  Firebase를 직접 참조할 수 없다. 대신 앱 시작 시 CompositionRoot가 전송 클로저를
//  주입하고, 익스텐션 프로세스에서는 nil로 남아 no-op이 된다.
//

enum LiveActivityAnalyticsBridge {
    /// GA4 이벤트 전송 클로저 — (이벤트 이름, 파라미터). 본앱 프로세스에서만 주입된다.
    nonisolated(unsafe) static var log: (@Sendable (_ name: String, _ parameters: [String: String]) -> Void)?
}
