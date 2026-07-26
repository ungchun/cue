//
//  SupportLinks.swift
//  cue / Presentation
//

import Foundation

/// 지원/정보 섹션의 외부 링크 모음.
enum SupportLinks {
    /// ASC 앱 정보의 Apple ID — 강제 업데이트 알럿(RootView.appStoreURL)과 동일 값.
    static let appStoreID = "6789932436"

    /// 앱 공유 시트에 담을 앱스토어 페이지 링크.
    static var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)")!
    }

    /// 피드백 받을 개발자 이메일.
    static let feedbackEmail = "leedool3003@gmail.com"

    /// 피드백 메일 작성용 mailto 링크(제목 프리필).
    static var feedbackMailtoURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = feedbackEmail
        components.queryItems = [URLQueryItem(name: "subject", value: String(localized: "cue Feedback"))]
        return components.url!
    }
}

/// 앱 버전 표시 문자열.
enum AppVersionInfo {
    /// "1.0.0" 형태(빌드 번호 없이). Info.plist에서 읽는다.
    static var display: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}
