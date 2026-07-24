//
//  FirebaseAnalyticsService.swift
//  cue / Data
//
//  Firebase Analytics(GA4)로 이벤트를 전송한다. 외부 SDK 경계 글루 — RED 면제.
//

import FirebaseAnalytics

struct FirebaseAnalyticsService: AnalyticsService {
    func log(_ event: AnalyticsEvent) {
        Analytics.logEvent(event.name, parameters: event.parameters)
    }

    func log(name: String, parameters: [String: String]) {
        Analytics.logEvent(name, parameters: parameters)
    }
}
