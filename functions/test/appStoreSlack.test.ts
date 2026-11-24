/**
 * 슬랙 메시지 계약 — 어떤 알림을 보내고, 보낼 때 어떻게 보이는가.
 *
 * 서명 검증(JWS x5c 사슬)은 Apple 공식 라이브러리가 하고 여기서 테스트하지 않는다.
 */
import {test, describe} from "node:test";
import assert from "node:assert/strict";
import type {
  JWSRenewalInfoDecodedPayload,
  JWSTransactionDecodedPayload,
} from "@apple/app-store-server-library";

import {countryLabel, formatMoney, headlineFor, messageFor} from "../src/appStoreSlack";

const DAY_MS = 24 * 60 * 60 * 1000;
const PURCHASED_AT = Date.UTC(2026, 10, 1, 9, 0, 0);

function tx(fields: Record<string, unknown>): JWSTransactionDecodedPayload {
  return fields as unknown as JWSTransactionDecodedPayload;
}

function renewal(fields: Record<string, unknown>): JWSRenewalInfoDecodedPayload {
  return fields as unknown as JWSRenewalInfoDecodedPayload;
}

function titleOf(message: {blocks: object[]}): string {
  return (message.blocks[0] as {text: {text: string}}).text.text;
}

/** 박스 블록의 글자만 이어 붙인다 — 슬랙에 보이는 그대로. */
function boxOf(message: {blocks: object[]}): string {
  const box = message.blocks[1] as {elements: {elements: {text: string}[]}[]};
  return box.elements[0].elements.map((element) => element.text).join("");
}

describe("headlineFor — 보낼 알림과 제목", () => {
  test("구독 첫 결제", () => {
    const headline = headlineFor("SUBSCRIBED", "INITIAL_BUY", tx({}));
    assert.equal(headline?.title, "Subscription");
    assert.equal(headline?.money, true);
  });

  test("무료 체험으로 시작한 구독은 Free trial로 갈라 보인다", () => {
    const headline = headlineFor("SUBSCRIBED", "INITIAL_BUY", tx({offerDiscountType: "FREE_TRIAL"}));
    assert.equal(headline?.title, "Free trial");
  });

  test("체험이 끝나고 처음 돈이 들어오는 DID_RENEW를 보낸다", () => {
    const headline = headlineFor("DID_RENEW", undefined, tx({}));
    assert.equal(headline?.title, "Renewal");
    assert.equal(headline?.money, true);
  });

  test("결제 실패 뒤 회복된 갱신은 따로 표시한다", () => {
    assert.equal(headlineFor("DID_RENEW", "BILLING_RECOVERY")?.title, "Renewal · billing recovered");
  });

  test("평생 이용권 결제", () => {
    const headline = headlineFor("ONE_TIME_CHARGE", undefined, tx({}));
    assert.equal(headline?.title, "Purchase");
    assert.equal(headline?.money, true);
  });

  test("자동 갱신을 끄면 체험 중인지 구독 중인지로 갈라 보인다", () => {
    const trial = headlineFor("DID_CHANGE_RENEWAL_STATUS", "AUTO_RENEW_DISABLED", tx({offerDiscountType: "FREE_TRIAL"}));
    const paid = headlineFor("DID_CHANGE_RENEWAL_STATUS", "AUTO_RENEW_DISABLED", tx({}));
    assert.equal(trial?.title, "Cancel (Free trial)");
    assert.equal(trial?.mark, "🟡");
    assert.equal(paid?.title, "Cancel (Subscription)");
  });

  test("환불", () => {
    const headline = headlineFor("REFUND", undefined, tx({}));
    assert.equal(headline?.title, "Refund");
    assert.equal(headline?.mark, "🔴");
  });

  test("안 보내는 알림 — 테스트, 자발적 만료, 갱신 실패 재시도, 가족 공유 해제", () => {
    assert.equal(headlineFor("TEST"), undefined);
    assert.equal(headlineFor("EXPIRED", "VOLUNTARY"), undefined);
    assert.equal(headlineFor("DID_FAIL_TO_RENEW", "GRACE_PERIOD"), undefined);
    assert.equal(headlineFor("REVOKE"), undefined);
  });
});

describe("formatMoney — price는 1000배 값", () => {
  test("원·엔은 소수점 없이", () => {
    assert.equal(formatMoney(39_000_000, "KRW"), "₩39,000");
    assert.equal(formatMoney(1_100_000, "JPY"), "¥1,100");
  });

  test("기호가 세 글자 코드로 나오는 통화는 좁은 기호로", () => {
    assert.equal(formatMoney(199_000, "THB"), "฿199");
  });

  test("달러 계열은 어느 나라 달러인지 남긴다", () => {
    assert.equal(formatMoney(9_990, "USD"), "$9.99");
    assert.equal(formatMoney(1_490_000, "TWD"), "NT$1,490");
    assert.equal(formatMoney(4_990, "CAD"), "CA$4.99");
  });
});

describe("countryLabel", () => {
  test("storefront 세 글자를 국기와 나라 이름으로", () => {
    assert.equal(countryLabel("KOR"), "🇰🇷 South Korea");
  });

  test("모르는 storefront는 코드 그대로", () => {
    assert.equal(countryLabel("ZZZ"), "ZZZ");
  });
});

describe("messageFor — 슬랙에 보이는 모양", () => {
  const lifetime = tx({
    productId: "azhy.cue.premium.lifetime",
    storefront: "KOR",
    price: 39_000_000,
    currency: "KRW",
    appTransactionId: "705123",
    originalTransactionId: "2000001",
    originalPurchaseDate: PURCHASED_AT,
  });

  test("평생 이용권 원화 결제 — 제목, 박스, 미리보기", () => {
    const headline = headlineFor("ONE_TIME_CHARGE", undefined, lifetime);
    assert.ok(headline);
    const message = messageFor({headline, tx: lifetime, signedDate: PURCHASED_AT});

    assert.equal(titleOf(message), "🟢 *Purchase*   ₩39,000");
    assert.equal(boxOf(message), [
      "Plan      Lifetime",
      "Country   🇰🇷 South Korea",
      "Type      Full price",
      "Account   705123",
      "Tx        2000001",
    ].join("\n"));
    assert.equal(message.text, "🟢 Purchase ₩39,000 · Lifetime · 🇰🇷 South Korea");
  });

  test("해외 결제는 원화 환산을 붙인다", () => {
    const monthly = tx({productId: "azhy.cue.premium.monthly", storefront: "THA", price: 199_000, currency: "THB"});
    const headline = headlineFor("SUBSCRIBED", "INITIAL_BUY", monthly);
    assert.ok(headline);
    const message = messageFor({headline, tx: monthly, krw: 7_900});
    assert.equal(titleOf(message), "🟢 *Subscription*   ฿199 (≈ ₩7,900)");
  });

  test("해지 예약에는 금액·결제 유형 대신 사용 일수가 붙는다", () => {
    const yearly = tx({
      productId: "azhy.cue.premium.yearly",
      storefront: "JPN",
      originalPurchaseDate: PURCHASED_AT,
      appTransactionId: "705999",
    });
    const headline = headlineFor("DID_CHANGE_RENEWAL_STATUS", "AUTO_RENEW_DISABLED", yearly);
    assert.ok(headline);
    const message = messageFor({headline, tx: yearly, signedDate: PURCHASED_AT + 8 * DAY_MS + 3_600_000});

    assert.equal(titleOf(message), "🟡 *Cancel (Subscription)*");
    const box = boxOf(message);
    assert.match(box, /^Tenure {4}Day 8$/m);
    assert.doesNotMatch(box, /^Type/m);
  });

  test("다음 갱신 상품이 다르면 어디서 어디로 바뀌는지 보인다", () => {
    const monthly = tx({productId: "azhy.cue.premium.monthly"});
    const headline = headlineFor("DID_CHANGE_RENEWAL_PREF", "UPGRADE", monthly);
    assert.ok(headline);
    const message = messageFor({
      headline, tx: monthly, renewal: renewal({autoRenewProductId: "azhy.cue.premium.yearly"}),
    });
    assert.match(boxOf(message), /^Plan +Monthly → Yearly$/m);
  });

  test("가족 공유로 받은 권한은 표시한다", () => {
    const shared = tx({productId: "azhy.cue.premium.lifetime", inAppOwnershipType: "FAMILY_SHARED"});
    const headline = headlineFor("ONE_TIME_CHARGE", undefined, shared);
    assert.ok(headline);
    assert.match(boxOf(messageFor({headline, tx: shared})), /^Owner +Family Sharing$/m);
  });

  test("샌드박스 결제는 제목과 미리보기에 표시한다", () => {
    const headline = headlineFor("ONE_TIME_CHARGE", undefined, lifetime);
    assert.ok(headline);
    const message = messageFor({headline, tx: lifetime, sandbox: true});
    assert.equal(titleOf(message), "🟢 *Purchase*   ₩39,000   🧪 _Sandbox_");
    assert.ok(message.text.startsWith("🧪 🟢 Purchase"));
  });

  test("지갑 칸은 없다 — cue에는 계정이 없다", () => {
    const headline = headlineFor("ONE_TIME_CHARGE", undefined, lifetime);
    assert.ok(headline);
    assert.doesNotMatch(boxOf(messageFor({headline, tx: lifetime})), /Wallet/);
  });
});
