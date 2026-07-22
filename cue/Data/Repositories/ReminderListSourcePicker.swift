//
//  ReminderListSourcePicker.swift
//  cue / Data
//
//  새 미리알림 리스트를 만들 계정(EKSource) 선택의 순수 정책.
//  이름("iCloud") 매칭이 아니라 **능력(미리알림 리스트 보유) 기준** — iCloud 미리알림
//  동기화가 꺼진 기기에서 이름만 보고 iCloud를 찍으면 "해당 계정은 미리 알림을 지원하지
//  않습니다" 저장 실패가 난다. EventKit 타입과 분리해 우선순위 로직만 단위 테스트한다.
//

enum ReminderListSourcePicker {
    /// EKSource의 판정 재료 스냅샷 — 리포지토리가 매핑해 넘긴다.
    struct Candidate: Equatable, Sendable {
        let id: String
        /// CalDAV + iCloud 계정인가.
        let isICloud: Bool
        /// 미리알림 리스트를 하나라도 갖고 있는가 = 미리알림을 실제 지원하는가.
        let hasReminderCalendars: Bool
    }

    /// 우선순위: ① 기본 미리알림 리스트의 source(항상 안전) → ② 미리알림을 가진 iCloud →
    /// ③ 미리알림을 가진 아무 계정 → ④ nil(호출처가 안내 에러). 지원 안 하는 계정은 절대 안 찍는다.
    static func pick(from candidates: [Candidate], defaultSourceID: String?) -> String? {
        if let defaultSourceID, candidates.contains(where: { $0.id == defaultSourceID }) {
            return defaultSourceID
        }
        if let iCloud = candidates.first(where: { $0.isICloud && $0.hasReminderCalendars }) {
            return iCloud.id
        }
        return candidates.first(where: \.hasReminderCalendars)?.id
    }
}
