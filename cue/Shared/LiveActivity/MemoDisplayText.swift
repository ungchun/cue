//
//  MemoDisplayText.swift
//  cue / Shared
//

import Foundation

// MARK: - 타깃 멤버십
//
// 위젯 익스텐션(메모 LA 렌더)과 앱(설정 미리보기·유닛 테스트) 양쪽이 쓴다 — 두 타깃에 들어간다
// (pbxproj exception). Foundation만 참조하는 순수 규칙이라 어느 타깃에서도 안전하다.

/// 메모를 그리기 직전에 통과시키는 **줄바꿈 규칙**.
///
/// **왜 필요한가** — iOS의 SwiftUI `Text`는 한글에 **어절 우선**(`hangulWordPriority`) 줄바꿈
/// 전략을 쓴다. `"메모를 입력하세요ㅇㅇㅇ…ㅇ"`에서 뒤쪽 어절을 쪼개지 않고 통째로 다음 줄로 밀어,
/// 첫 줄에 자리가 남는데도 `"메모를"`만 남는 짧은 줄이 생긴다(기기 스크린샷으로 확인).
/// 앱 메모 입력칸(`GrowingTextView`/UITextView)은 이 전략을 쓰지 않아 같은 문자열이 정상으로
/// 채워진다 — 같은 iOS 안에서도 렌더러마다 전략이 달라서 위젯·미리보기에서만 나타났다.
///
/// **왜 ZWSP인가** — U+200B은 UAX #14의 line-break class **ZW**라 어떤 전략을 쓰든 그 자리가
/// 구조적인 끊을 기회가 된다(LB8). 어절 우선 전략보다 우선한다.
///
/// **검증** — iOS 26.5 시뮬레이터에 위젯과 같은 렌더 조건을 올려 12개 언어를 전·후 비교했다.
/// 한국어·독일어·러시아어에서 첫 줄 낭비와 최대 축소가 사라지고, 나머지 언어는 전·후가 동일하다.
/// (macOS CoreText는 같은 문자열을 이미 음절 경계에서 쪼개 이 증상이 재현되지 않는다 — 맥에서
/// 재는 것으로는 확인할 수 없다.)
///
/// **어떻게** — 임계 길이를 넘는 토큰 안에만 zero-width space(U+200B)를 심는다. 폭 0이라 글자
/// 모양·간격을 바꾸지 않고, 끊을 자리를 *허용*만 하므로 한 줄에 들어가는 토큰은 그대로 한 줄이다.
/// 짧은 단어를 건드리지 않는 이유 — 평범한 문장이 어절 중간에서 끊기면 읽기가 나빠진다.
enum MemoDisplayText {

    /// 이 길이(글자 수)를 **넘는** 토큰만 쪼갤 수 있게 만든다.
    ///
    /// 8 — LA 카드 한 줄에 들어가는 한글은 "크게"(34pt)에서 9자 안팎이다. 임계를 그보다 낮게
    /// 잡아야 한 줄을 넘길 만한 토큰이 빠짐없이 걸린다. 10이면 9~10자 토큰이 그물을 빠져나가
    /// 같은 증상이 남는다. 낮춰도 짧은 메모엔 영향이 없다 — ZWSP는 끊을 자리를 *허용*만 하고,
    /// 한 줄에 들어가는 토큰은 그대로 한 줄로 남는다.
    static let longTokenThreshold = 8

    private static let zeroWidthSpace: Character = "\u{200B}"

    /// 긴 토큰 안에 끊을 기회를 심은 표시용 문자열. 공백·줄바꿈은 개수까지 그대로 보존한다.
    ///
    /// 이미 처리된 문자열을 다시 넣어도 결과가 같다(먼저 기존 ZWSP를 걷어낸다) —
    /// 미리보기가 값 변경마다 다시 그리므로 겹겹이 쌓이면 안 된다.
    static func breakable(_ text: String) -> String {
        let cleaned = String(text.filter { $0 != zeroWidthSpace })
        var output = ""
        var token = ""

        // 토큰이 임계를 넘으면 자소(Character) 경계마다 기회를 심는다 — 이모지·결합 문자가
        // 중간에서 쪼개지지 않도록 스칼라가 아니라 Character 단위로 다룬다.
        func flushToken() {
            guard !token.isEmpty else { return }
            if token.count > longTokenThreshold, !isProtectedScript(token) {
                output += token.map(String.init).joined(separator: String(zeroWidthSpace))
            } else {
                output += token
            }
            token = ""
        }

        for character in cleaned {
            if character.isWhitespace {
                flushToken()
                output.append(character)
            } else {
                token.append(character)
            }
        }
        flushToken()

        return output
    }

    /// 손대면 **오히려 나빠지는** 문자가 섞였는지 — 두 부류다(시뮬레이터 실측으로 확정).
    ///
    /// ① **이어 쓰는 문자**(아랍·시리아·응코·만다익·몽골·아들람) — ZWSP는 joining type이
    ///    "비연결"이라 사이에 끼우면 이음이 끊겨 낱글자(고립형)로 렌더된다. 렌더 폭 +41% 확인.
    ///
    /// ② **끊을 자리를 스스로 아는 문자**(한자·가나·주음, 태국·라오·크메르·버마) — 공백이 없어도
    ///    시스템이 알아서 줄을 나눈다. 도움이 필요 없을 뿐 아니라, ZWSP를 넣으면 시스템의 금칙
    ///    규칙을 덮어써서 중국어 쉼표(`，`)가 줄 첫머리로 넘어가는 등 조판이 망가진다(실측).
    ///
    /// 한글은 제외 대상이 아니다 — 이 함수가 존재하는 이유가 한글이다. 자모 영역(U+3130–318F)이
    /// CJK 기호 영역 사이에 끼어 있어 범위를 일부러 건너뛴다. 라틴·키릴·히브리·인도계는 안전하고,
    /// 인도계 결합 자음은 Swift의 자소(Character) 단위 분해가 이미 한 덩어리로 유지한다.
    private static func isProtectedScript(_ token: String) -> Bool {
        token.unicodeScalars.contains { scalar in
            return switch scalar.value {
            // ① 이어 쓰는 문자
            case 0x0600...0x06FF,     // Arabic
                 0x0700...0x074F,     // Syriac
                 0x0750...0x077F,     // Arabic Supplement
                 0x07C0...0x07FF,     // NKo
                 0x0840...0x085F,     // Mandaic
                 0x0860...0x08FF,     // Syriac Supplement · Arabic Extended-A/B
                 0x1800...0x18AF,     // Mongolian
                 0xFB50...0xFDFF,     // Arabic Presentation Forms-A
                 0xFE70...0xFEFF,     // Arabic Presentation Forms-B
                 0x1E900...0x1E95F:   // Adlam
                true
            // ② 스스로 끊는 문자 — CJK(한글 자모 영역 U+3130–318F는 건너뛴다)
            case 0x2E80...0x303F,     // CJK 부수 · 강희 부수 · CJK 기호와 구두점
                 0x3040...0x312F,     // 히라가나 · 가타카나 · 주음부호
                 0x3190...0x4DBF,     // 간분 · CJK 확장 A
                 0x4E00...0x9FFF,     // CJK 통합 한자
                 0xF900...0xFAFF,     // CJK 호환 한자
                 0xFE30...0xFE4F,     // CJK 호환 형태
                 0xFF00...0xFFEF,     // 전각/반각 형태
                 0x20000...0x3FFFF:   // CJK 확장 B 이상
                true
            // ② 스스로 끊는 문자 — 사전 기반 줄바꿈을 쓰는 동남아 문자
            case 0x0E00...0x0EFF,     // Thai · Lao
                 0x1000...0x109F,     // Myanmar
                 0x1780...0x17FF:     // Khmer
                true
            default:
                false
            }
        }
    }
}
