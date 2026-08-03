//
//  MemoDisplayTextTests.swift
//  cueTests
//
//  메모 LA·미리보기가 그리기 직전에 통과시키는 줄바꿈 규칙.
//

import Foundation
import Testing
@testable import cue

/// 공백 없는 긴 토큰이 카드 폭을 낭비하던 문제의 규칙.
///
/// 증상(2026-08-03 보고): `"메모를 입력하세요ㅇㅇㅇ…ㅇ"`를 넣으면 잠금화면 LA와 설정
/// 미리보기가 1줄에 `"메모를"`만 두고 2줄에 나머지를 몰아 그린다. 첫 줄에 자리가 남는데도
/// 줄이 끊긴다.
///
/// 원인 — iOS SwiftUI `Text`는 한글에 **어절 우선**(`hangulWordPriority`) 줄바꿈 전략을 써서
/// `"입력하세요ㅇㅇㅇ…ㅇ"`를 쪼개지 않고 통째로 다음 줄로 민다. 앱 메모 입력칸(`GrowingTextView`,
/// UITextView)은 그 전략을 쓰지 않아 같은 문자열이 정상으로 채워졌다.
///
/// 규칙 — 표시 직전에 **긴 토큰 안에만** zero-width space(U+200B)를 심어 끊을 기회를 준다.
/// ZWSP는 폭 0이라 글자 모양·간격을 바꾸지 않고, 끊을 자리를 "허용"할 뿐이라 한 줄에 들어가는
/// 토큰은 그대로 한 줄로 남는다. 짧은 단어는 손대지 않는다 — 평범한 문장이 어절 중간에서
/// 끊기면 오히려 읽기 나빠진다.
struct MemoDisplayTextTests {

    /// ZWSP — 눈에 보이지 않으므로 테스트에서 이름으로 다룬다.
    private let zwsp = "\u{200B}"

    // MARK: - 긴 토큰 — 끊을 기회를 심는다

    /// 보고된 그 문자열. 긴 토큰만 문자 단위로 끊을 수 있게 되고, 공백은 그대로다.
    @Test func insertsBreakOpportunitiesInsideLongToken() {
        let long = "입력하세요" + String(repeating: "ㅇ", count: 15)
        let result = MemoDisplayText.breakable("메모를 " + long)

        #expect(result.hasPrefix("메모를 "))
        // 심은 ZWSP를 걷어내면 원문과 같아야 한다 — 글자는 하나도 바뀌지 않는다.
        #expect(result.replacingOccurrences(of: zwsp, with: "") == "메모를 " + long)
        // 긴 토큰 안 모든 문자 경계에 기회가 생긴다 = 문자 수 - 1개.
        #expect(result.components(separatedBy: zwsp).count - 1 == long.count - 1)
    }

    /// 첫 줄에 짧은 어절이 남는 형태 자체가 사라졌는지 — 긴 토큰의 앞부분이 앞 어절에 이어
    /// 붙을 수 있어야 한다(= 토큰 시작 직후에도 끊을 자리가 있다).
    @Test func longTokenCanBreakAfterItsFirstCharacter() {
        let result = MemoDisplayText.breakable("메모를 " + String(repeating: "ㅇ", count: 20))
        #expect(result.contains("ㅇ" + zwsp + "ㅇ"))
    }

    // MARK: - 짧은 토큰 — 건드리지 않는다

    /// 평범한 문장은 그대로 통과한다. 어절 중간에서 끊기지 않아야 읽기가 유지된다.
    @Test func leavesOrdinarySentenceUntouched() {
        let text = "오늘 저녁 7시 약속 잊지 말기"
        #expect(MemoDisplayText.breakable(text) == text)
    }

    /// 임계 길이 이하의 단일 토큰도 그대로. 영어 단어가 중간에서 쪼개지지 않는다.
    @Test func leavesShortTokenUntouched() {
        #expect(MemoDisplayText.breakable("Standup") == "Standup")
    }

    /// 9자 한글 토큰도 걸려야 한다 — "크게"(34pt)에선 한 줄에 9자 안팎이라 이만큼만 돼도
    /// 앞 어절을 밀어내며 같은 증상이 난다. 임계가 10이던 시절 이 크기가 그물을 빠져나갔다.
    @Test func breaksNineCharacterKoreanToken() {
        let result = MemoDisplayText.breakable("오늘 " + String(repeating: "가", count: 9))
        #expect(result.contains("가" + zwsp + "가"))
    }

    // MARK: - 공백·줄바꿈 보존

    /// 줄바꿈과 공백은 개수까지 그대로 유지된다 — 사용자가 잡은 단락이 흐트러지면 안 된다.
    @Test func preservesWhitespaceAndNewlines() {
        let result = MemoDisplayText.breakable("첫줄\n\n둘째  줄")
        #expect(result == "첫줄\n\n둘째  줄")
    }

    /// 빈 문자열은 빈 문자열.
    @Test func handlesEmptyText() {
        #expect(MemoDisplayText.breakable("") == "")
    }

    // MARK: - 여러 번 통과해도 같은 결과

    /// 미리보기는 값이 바뀔 때마다 다시 그린다 — 이미 처리된 문자열을 다시 넣어도
    /// ZWSP가 겹겹이 쌓이지 않아야 한다.
    @Test func isIdempotent() {
        let once = MemoDisplayText.breakable("메모를 " + String(repeating: "ㅇ", count: 15))
        #expect(MemoDisplayText.breakable(once) == once)
    }

    // MARK: - 이어 쓰는 문자(아랍 계열) — 손대면 글자 모양이 깨진다

    /// 아랍 문자는 앞뒤 글자와 **이어져서** 모양이 바뀐다. ZWSP는 joining type이 "비연결"이라
    /// 사이에 끼우면 이음이 끊겨 낱글자(고립형)로 렌더된다 — 줄바꿈을 얻는 대신 단어가 깨진다.
    /// 그래서 이 계열이 섞인 토큰은 통째로 건드리지 않는다(원래 동작 = 어절 단위 줄바꿈).
    @Test func leavesArabicTokenUntouched() {
        let arabic = "استخدامالتطبيقات"
        #expect(MemoDisplayText.breakable(arabic) == arabic)
    }

    /// 아랍 토큰이 섞여 있어도 다른 토큰은 정상 처리된다 — 문장 전체를 포기하지 않는다.
    @Test func stillBreaksNonCursiveTokensInMixedText() {
        let result = MemoDisplayText.breakable("استخدامالتطبيقات " + String(repeating: "ㅇ", count: 15))
        #expect(result.contains("استخدامالتطبيقات "))
        #expect(result.contains("ㅇ" + zwsp + "ㅇ"))
    }

    // MARK: - 스스로 끊는 문자 — 시스템 조판을 덮어쓰면 안 된다

    /// 한자·가나는 공백이 없어도 시스템이 알아서 줄을 나누고, 구두점이 줄 첫머리에 오지 않도록
    /// 금칙 규칙을 적용한다. ZWSP를 넣으면 그 규칙이 무시돼 중국어 쉼표가 행두로 넘어간다
    /// (시뮬레이터 실측). 도움이 필요 없으므로 건드리지 않는다.
    @Test func leavesCJKUntouched() {
        let chinese = "记得明天上午九点开会，准备好所有资料。"
        let japanese = "明日の会議資料を準備することを忘れないでください。"
        #expect(MemoDisplayText.breakable(chinese) == chinese)
        #expect(MemoDisplayText.breakable(japanese) == japanese)
    }

    /// 태국어는 사전 기반으로 낱말 경계를 찾아 끊는다. ZWSP를 넣으면 낱말 중간에서 끊긴다.
    @Test func leavesThaiUntouched() {
        let thai = "อย่าลืมเตรียมเอกสารสำหรับการประชุมพรุ่งนี้"
        #expect(MemoDisplayText.breakable(thai) == thai)
    }

    /// 한글 자모(U+3130–318F)는 CJK 기호 영역 사이에 끼어 있다 — 제외 범위를 잘못 잡으면
    /// 보고된 그 문자열(`ㅇ` 반복)이 통째로 그물을 빠져나간다.
    @Test func stillBreaksHangulCompatibilityJamo() {
        let result = MemoDisplayText.breakable(String(repeating: "ㅇ", count: 12))
        #expect(result.contains("ㅇ" + zwsp + "ㅇ"))
    }

    // MARK: - 자소 경계

    /// 이모지·결합 문자는 한 글자로 다뤄 중간이 쪼개지지 않는다 — 쪼개면 렌더가 깨진다.
    @Test func doesNotSplitGraphemeClusters() {
        let family = String(repeating: "👨‍👩‍👧‍👦", count: 12)
        let result = MemoDisplayText.breakable(family)
        #expect(result.replacingOccurrences(of: zwsp, with: "") == family)
        #expect(result.components(separatedBy: zwsp).count - 1 == 11)
    }
}
