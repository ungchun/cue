//
//  DisabledAnalyticsService.swift
//  cue / Data
//
//  프리뷰·테스트용 no-op — 아무것도 기록하지 않는다. Firebase 없이도 뷰·VM이 동작한다.
//

struct DisabledAnalyticsService: AnalyticsService {
    func log(_ event: AnalyticsEvent) {}
}
