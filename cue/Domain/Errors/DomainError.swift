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
            "요청한 데이터를 찾을 수 없습니다."
        case .validation(let reason):
            reason
        case .persistenceFailed(let reason):
            "저장소 오류: \(reason)"
        case .unknown:
            "알 수 없는 오류가 발생했습니다."
        }
    }
}
