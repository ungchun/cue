//
//  KeyboardDismissToolbar.swift
//  cue / Presentation
//

import SwiftUI
import UIKit

extension View {
    /// 키보드가 올라오면 액세서리 바 **오른쪽**에 "완료" 버튼을 띄워 키보드를 내린다.
    ///
    /// `resignFirstResponder`를 시스템에 브로드캐스트해 현재 편집 중인 필드 종류(텍스트·
    /// 숫자패드 등)와 무관하게 닫는다 — 화면마다 `@FocusState`를 두고 nil로 비울 필요 없이
    /// 모든 입력 화면에 동일하게 적용된다. numberPad처럼 Return이 없는 키보드도 닫힌다.
    func keyboardDismissToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                }
            }
        }
    }
}
