//
//  AppLogger.swift
//  cue / Core
//

import Foundation
import OSLog

/// 앱 전역 로거. `os.Logger` 래퍼로 카테고리별 로그를 한 곳에서 관리한다.
///
/// 사용 예: `AppLogger.data.error("저장 실패: \(error)")`
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "azhy.cue"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let data = Logger(subsystem: subsystem, category: "data")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
