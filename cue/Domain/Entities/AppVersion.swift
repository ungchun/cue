//
//  AppVersion.swift
//  cue / Domain
//

import Foundation

/// 점 구분 버전("1.2.3")의 숫자 단위 비교값. 문자열 비교의 함정("1.10" < "1.9")을 피하고,
/// 자릿수가 달라도 의미가 같으면 같게 본다("1.0" == "1.0.0") — Remote Config에 어느 표기로
/// 넣어도 판정이 일관되도록.
struct AppVersion: Sendable {
    let components: [Int]

    init?(_ string: String) {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty, !string.isEmpty else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard let number = Int(part), number >= 0 else { return nil }
            numbers.append(number)
        }
        self.components = numbers
    }
}

extension AppVersion: Comparable {
    /// 짧은 쪽을 0으로 채워 자릿수를 맞춘 뒤 사전식 비교.
    private static func padded(_ lhs: Self, _ rhs: Self) -> ([Int], [Int]) {
        let count = max(lhs.components.count, rhs.components.count)
        func pad(_ values: [Int]) -> [Int] {
            values + Array(repeating: 0, count: count - values.count)
        }
        return (pad(lhs.components), pad(rhs.components))
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        let (left, right) = padded(lhs, rhs)
        return left == right
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        let (left, right) = padded(lhs, rhs)
        for (l, r) in zip(left, right) where l != r {
            return l < r
        }
        return false
    }
}
