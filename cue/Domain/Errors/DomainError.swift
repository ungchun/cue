//
//  DomainError.swift
//  cue / Domain
//

import Foundation

/// 도메인 계층 오류. Data 계층은 하위 오류(SwiftData 등)를 이 타입으로 변환해 전달한다.
enum DomainError: Error, Equatable {
    case notFound
    case validation(String)
    case persistenceFailed(String)
    case unknown
}

extension DomainError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notFound:
            String(localized: "The requested data could not be found.")
        case .validation(let reason):
            reason
        case .persistenceFailed(let reason):
            String(localized: "Storage error: \(reason)")
        case .unknown:
            String(localized: "An unknown error occurred.")
        }
    }
}
