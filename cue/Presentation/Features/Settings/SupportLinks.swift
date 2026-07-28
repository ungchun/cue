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

    /// App Store 리뷰 **작성** 화면을 바로 여는 링크.
    ///
    /// 사용자가 직접 누르는 버튼은 `requestReview`를 쓰지 않는다 — Apple 문서가 명시적으로
    /// 금지한다("don't call it in response to a button tap"). 1년 3회 한도에 걸리거나 사용자가
    /// 리뷰 요청을 꺼두면 **아무 일도 안 일어나** 버튼이 고장 난 것처럼 보이기 때문.
    /// 이 링크는 항상 열리고, 별점뿐 아니라 글도 남길 수 있다.
    static var writeReviewURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
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
