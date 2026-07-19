//
//  DisabledAppUpdatePolicyService.swift
//  cue / Data
//
//  프리뷰·테스트용 no-op — 항상 nil(강제 업데이트 없음). Firebase 없이도 뷰가 뜬다.
//

struct DisabledAppUpdatePolicyService: AppUpdatePolicyService {
    func minimumRequiredVersion() async -> AppVersion? { nil }
}
