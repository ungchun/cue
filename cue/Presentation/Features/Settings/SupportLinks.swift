//
//  SupportLinks.swift
//  cue / Presentation
//

import Foundation

/// 지원/정보 섹션의 외부 링크 모음. 앱스토어 ID는 출시 후 실제 값으로 교체한다.
enum SupportLinks {
    /// TODO: 앱스토어 출시 후 실제 앱 ID로 교체. (현재 placeholder)
    static let appStoreID = "0000000000"

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
        components.queryItems = [URLQueryItem(name: "subject", value: "cue 피드백")]
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
