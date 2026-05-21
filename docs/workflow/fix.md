---
참조: [docs/tdd.md, docs/testing.md, docs/workflow/debug.md, docs/design-system.md]
---

# 워크플로우 — fix (버그 수정)

알려진 버그를 **근본 원인 기반**으로 고친다. 땜질하지 않는다.

사이클: `(debug 진단) → refactor=수정 → verify`

## 순서

1. **원인 확보** — 원인을 모르면 먼저 [debug](debug.md)로 진단한다.
   debug가 *재현하는 실패 테스트(red)* + *근본 원인*을 넘겨준다.
2. **red** — (debug를 거치지 않았다면) 버그를 재현하는 실패 테스트를 먼저 작성한다.
   테스트가 처음부터 통과하면 → 버그를 잘못 짚은 것. 원인을 다시 본다.
3. **refactor = 수정** — 버그가 있던 코드와 주변 설계를 개선한다. 이 과정에서 버그가
   고쳐진다. 빠른 땜질(quick patch)은 피한다.
4. **verify** — 전체 테스트를 돌려 회귀(regression) 0건 확인.

## 왜 이렇게

버그는 그 자체로 문제이기도 하지만 더 깊은 설계·품질 문제의 *증상*인 경우가 많다.
재현 테스트는 그 버그를 영구히 고정하고, 주변 품질 개선은 근본 원인을 완화해
같은 버그의 재발(regression)을 막는다.

## 뷰를 건드린다면

[design-system.md](../design-system.md) 규칙을 따른다.

커밋: `fix:` (debug 단계는 별도 커밋하지 않고 fix에 흡수)
