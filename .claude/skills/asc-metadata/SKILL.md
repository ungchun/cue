---
name: asc-metadata
description: App Store Connect에 fastlane 메타데이터를 "있는 그대로" 올린다. 사용자가 ASC에 새 버전을 "제출 준비 중"으로 만들어 둔 상태에서 "메타데이터 올려", "fastlane 올려", "ASC 올려" 같은 요청이 오면 사용한다. 릴리스 노트·설명 등 어떤 문구도 수정하지 않고 로컬 파일 그대로 업로드하는 것이 핵심 계약이다.
---

# asc-metadata — 메타데이터 그대로 올리기

fastlane `upload_metadata`로 `fastlane/metadata/`를 App Store Connect에 올린다.

## 🔴 절대 규칙

1. **어떤 메타데이터 파일도 수정하지 않는다.** 릴리스 노트·설명·키워드·이름·부제목
   전부 로컬에 있는 그대로 올린다. 문구 작성·수정은 이 스킬의 일이 아니다 —
   사용자가 명시적으로 "문구 바꿔줘"라고 한 경우에도, 바꿀 내용을 **먼저 보여주고
   확인받은 뒤에만** 수정한다 (2026-08-16 릴리스 노트 임의 수정 사고의 재발 방지).
2. 스크린샷·바이너리는 올리지 않는다 (`upload_metadata` lane이 이미 스킵).
3. 확인 범위는 "ASC에 준비 중 버전이 있는가"까지다. 심사 제출·릴리스 타입 설정은
   사용자 몫이다.

## 절차

### 1. ASC의 편집 가능 버전 확인

사용자가 미리 만들어 둔 "제출 준비 중" 버전 번호를 알아낸다:

```bash
cat > /tmp/asc_edit_version.rb <<'EOF'
require 'spaceship'
Spaceship::ConnectAPI.login(
  CredentialsManager::AppfileConfig.try_fetch_value(:apple_id),
  use_portal: false, use_tunes: true,
  tunes_team_id: CredentialsManager::AppfileConfig.try_fetch_value(:itc_team_id)
)
app = Spaceship::ConnectAPI::App.find(CredentialsManager::AppfileConfig.try_fetch_value(:app_identifier))
v = app.get_edit_app_store_version
if v
  puts "EDIT_VERSION=#{v.version_string} STATE=#{v.app_store_state}"
else
  puts "NO_EDIT_VERSION"
end
EOF
ruby /tmp/asc_edit_version.rb
```

- `NO_EDIT_VERSION` → **멈추고** 사용자에게 "ASC에 준비 중 버전이 없다"고 알린다.
  버전 생성은 사용자가 한다.
- 세션 쿠키가 만료돼 2FA를 물으면 멈추고 `! fastlane upload_metadata version:<버전>`
  직접 실행을 안내한다 (대화형 입력은 에이전트가 못 받는다).

### 2. 업로드

1에서 얻은 버전으로:

```bash
fastlane upload_metadata version:<버전>
```

- 실행 전 `git status`로 `fastlane/metadata/`에 의도치 않은 로컬 변경이 없는지
  확인한다. 있으면 **올리기 전에** 사용자에게 diff를 보여주고 물어본다.
- `version:`을 생략하지 않는다 — deliver가 다른 버전을 집는 사고 방지
  (lane이 이 인자를 받도록 만들어 둔 이유).

### 3. 결과 보고

- 성공: 버전 번호 + 올라간 로케일 수(16개 정상)를 보고한다.
- 실패 로그에 "Making sure the latest version matches"가 보이면 ASC 버전과
  지정 버전이 다른 것이다 — 1로 돌아가 실제 버전을 다시 확인한다.

## 참고

- 로케일 16개: ko + en-US·ja·zh-Hans·zh-Hant·de-DE·fr-FR·es-ES·it·pt-BR·ru·ar-SA·hi·id·th·vi (ms는 ASC 미지원).
- 새 로케일 추가 시엔 `fastlane add_localizations` 먼저 (이름 충돌 우회) — 그건 이 스킬 밖의 일이다.
- 인증: Appfile의 Apple ID·팀. 저장된 spaceship 세션이 있으면 2FA 없이 통과된다.
