fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios add_localizations

```sh
[bundle exec] fastlane ios add_localizations
```

누락된 언어의 App Info 현지화를 metadata의 고유 이름으로 먼저 생성한다 (기본 이름 'Cue' 복사로 인한 이름 충돌 우회)

### ios upload_metadata

```sh
[bundle exec] fastlane ios upload_metadata
```

메타데이터만 App Store Connect에 업로드한다 (바이너리·스크린샷 제외)

버전 지정: fastlane upload_metadata version:1.0.9

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

스크린샷만 App Store Connect에 업로드한다 (메타데이터 제외, 기존 스크린샷 덮어씀)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
