//
//  KeychainLiveActivationQuotaRepository.swift
//  cue / Data
//
//  라이브 활성화 쿼터를 Keychain에 보관한다 — UserDefaults와 달리 **앱을 삭제해도
//  기기에 남아**, 재설치로 최초 사용일(첫날 2회)·오늘 사용량을 리셋하는 우회를 막는다.
//  `ThisDeviceOnly`로 iCloud 키체인 동기화·새 기기 이전을 차단한다(기기당 쿼터).
//  Security 프레임워크 경계 글루 — RED 면제(로직은 ConsumeLiveActivationUseCase가 검증).
//

import Foundation
import Security

actor KeychainLiveActivationQuotaRepository: LiveActivationQuotaRepository {
    private let service = "azhy.cue.liveActivationQuota"
    private let account = "quota"

    func fetch() -> LiveActivationQuota {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let quota = try? JSONDecoder().decode(LiveActivationQuota.self, from: data) else {
            return .empty
        }
        return quota
    }

    func save(_ quota: LiveActivationQuota) {
        guard let data = try? JSONEncoder().encode(quota) else { return }

        // update 먼저 시도, 항목이 없으면 add — 표준 upsert 패턴.
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        guard updateStatus == errSecItemNotFound else { return }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        // 첫 잠금해제 이후 접근 + 이 기기 전용(백업·iCloud로 다른 기기에 이전되지 않음).
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
