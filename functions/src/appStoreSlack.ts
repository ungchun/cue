import * as logger from "firebase-functions/logger";
import {
  Environment,
  InAppOwnershipType,
  JWSRenewalInfoDecodedPayload,
  JWSTransactionDecodedPayload,
  ResponseBodyV2DecodedPayload,
} from "@apple/app-store-server-library";
import {decodeRenewalInfo, decodeTransactionInfo} from "./appStore";

/**
 * App Store 알림을 슬랙(#cue-rocket)에 한 건씩 띄운다. Trace(functions/src/appStoreSlack.ts)에서 옮겼고,
 * Trace의 지갑(Wallet) 칸만 뺐다 — cue에는 계정·지갑이 없다.
 *
 * **절대 던지지 않는다.** 슬랙이 죽어도 Apple에는 늘 200이 나가야 한다.
 * 채널을 옮길 때는 같은 슬랙 앱에서 새 웹훅을 받아 시크릿 값만 바꾼다.
 */
export const SLACK_WEBHOOK_SECRET = "SLACK_APPSTORE_WEBHOOK_URL";

/** 응답 전에 보내므로 Apple 응답이 이만큼 늦어질 수 있다. */
const SLACK_TIMEOUT_MS = 3000;
const RATES_TIMEOUT_MS = 2000;
const RATES_TTL_MS = 6 * 60 * 60 * 1000;
/** 무료·키 없음, 하루 한 번 갱신. 값은 "1원이 그 통화로 얼마인가". */
const RATES_URL = "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/krw.json";
const DAY_MS = 24 * 60 * 60 * 1000;

interface Headline {
  mark: string;
  title: string;
  /** 돈이 들어온 알림 — 결제 유형(Type) 칸을 붙인다. */
  money?: boolean;
}

/**
 * 보낼 알림. `타입/서브타입`이 먼저, 없으면 `타입`만으로 찾는다. 목록에 없으면 안 보낸다.
 *
 * Trace와 다른 점: **DID_RENEW를 보낸다.** cue는 월·연 구독이 7일 무료 체험으로 시작해서,
 * 체험이 끝나고 처음 돈이 들어오는 순간이 INITIAL_BUY가 아니라 DID_RENEW로 온다. 이걸 빼면
 * 실제 결제를 하나도 못 본다. 건수가 많아지면 이 줄만 지운다.
 *
 * 일부러 뺀 것: DID_FAIL_TO_RENEW(재시도가 끝내 실패하면 EXPIRED/BILLING_RETRY로 다시 온다),
 * EXPIRED/VOLUNTARY(해지 예약 때 이미 알렸다), REVOKE(가족 공유 해제, 돈과 무관), TEST.
 */
const HEADLINES = new Map<string, Headline>([
  ["SUBSCRIBED/INITIAL_BUY", {mark: "🟢", title: "Subscription", money: true}],
  ["SUBSCRIBED/RESUBSCRIBE", {mark: "🟢", title: "Resubscription", money: true}],
  ["DID_RENEW/BILLING_RECOVERY", {mark: "🟢", title: "Renewal · billing recovered", money: true}],
  ["DID_RENEW", {mark: "🟢", title: "Renewal", money: true}],
  ["OFFER_REDEEMED", {mark: "🟢", title: "Offer redemption", money: true}],
  ["ONE_TIME_CHARGE", {mark: "🟢", title: "Purchase", money: true}],
  ["DID_CHANGE_RENEWAL_STATUS/AUTO_RENEW_DISABLED", {mark: "🟡", title: "Cancel"}],
  ["DID_CHANGE_RENEWAL_STATUS/AUTO_RENEW_ENABLED", {mark: "🟢", title: "Auto-renew on"}],
  ["DID_CHANGE_RENEWAL_PREF/UPGRADE", {mark: "🔄", title: "Plan change · immediate"}],
  ["DID_CHANGE_RENEWAL_PREF/DOWNGRADE", {mark: "🔄", title: "Plan change · next renewal"}],
  ["DID_CHANGE_RENEWAL_PREF", {mark: "🔄", title: "Plan change canceled"}],
  ["EXPIRED/BILLING_RETRY", {mark: "🔴", title: "Expiration · billing failed"}],
  ["EXPIRED/PRICE_INCREASE", {mark: "🔴", title: "Expiration · price increase declined"}],
  ["EXPIRED/PRODUCT_NOT_FOR_SALE", {mark: "🔴", title: "Expiration · product removed"}],
  ["REFUND", {mark: "🔴", title: "Refund"}],
  ["REFUND_REVERSED", {mark: "🟢", title: "Refund reversal"}],
]);

export function headlineFor(
  type?: string, subtype?: string, tx?: JWSTransactionDecodedPayload,
): Headline | undefined {
  const key = `${type ?? ""}/${subtype ?? ""}`;
  const headline = HEADLINES.get(key) ?? HEADLINES.get(type ?? "");
  if (!headline) return undefined;
  // 트라이얼은 돈이 안 오가므로 제목에서 구독과 갈라 보인다.
  const trial = tx?.offerDiscountType === "FREE_TRIAL";
  if (key === "SUBSCRIBED/INITIAL_BUY" && trial) return {...headline, title: "Free trial"};
  if (key === "DID_CHANGE_RENEWAL_STATUS/AUTO_RENEW_DISABLED") {
    return {...headline, title: trial ? "Cancel (Free trial)" : "Cancel (Subscription)"};
  }
  return headline;
}

/** `cue/Domain/Entities/PremiumProduct.swift`의 상품 id와 맞춘다. 모르는 id는 그대로 보인다. */
const PLAN_NAMES = new Map<string, string>([
  ["azhy.cue.premium.monthly", "Monthly"],
  ["azhy.cue.premium.yearly", "Yearly"],
  ["azhy.cue.premium.lifetime", "Lifetime"],
]);

function planName(productId: string): string {
  return PLAN_NAMES.get(productId) ?? productId;
}

/** App Store storefront(세 글자) → 두 글자. 목록에 없는 나라는 세 글자 코드 그대로 보인다. */
const STOREFRONTS = new Map(
  ("AFGAF ALBAL DZADZ AGOAO AIAAI ATGAG ARGAR ARMAM AUSAU AUTAT AZEAZ BHSBS BHRBH BRBBB BLRBY " +
  "BELBE BLZBZ BENBJ BMUBM BTNBT BOLBO BIHBA BWABW BRABR VGBVG BRNBN BGRBG BFABF KHMKH CMRCM " +
  "CANCA CPVCV CYMKY TCDTD CHLCL CHNCN COLCO CODCD COGCG CRICR CIVCI HRVHR CYPCY CZECZ DNKDK " +
  "DMADM DOMDO ECUEC EGYEG SLVSV ESTEE SWZSZ FJIFJ FINFI FRAFR GABGA GMBGM GEOGE DEUDE GHAGH " +
  "GRCGR GRDGD GTMGT GNBGW GUYGY HNDHN HKGHK HUNHU ISLIS INDIN IDNID IRQIQ IRLIE ISRIL ITAIT " +
  "JAMJM JPNJP JORJO KAZKZ KENKE KORKR XKSXK KWTKW KGZKG LAOLA LVALV LBNLB LBRLR LBYLY LTULT " +
  "LUXLU MACMO MDGMG MWIMW MYSMY MDVMV MLIML MLTMT MRTMR MUSMU MEXMX FSMFM MDAMD MNGMN MNEME " +
  "MSRMS MARMA MOZMZ MMRMM NAMNA NRUNR NPLNP NLDNL NZLNZ NICNI NERNE NGANG MKDMK NORNO OMNOM " +
  "PAKPK PLWPW PANPA PNGPG PRYPY PERPE PHLPH POLPL PRTPT QATQA ROURO RUSRU RWARW KNAKN LCALC " +
  "VCTVC WSMWS STPST SAUSA SENSN SRBRS SYCSC SLESL SGPSG SVKSK SVNSI SLBSB ZAFZA ESPES LKALK " +
  "SURSR SWESE CHECH TWNTW TJKTJ TZATZ THATH TONTO TTOTT TUNTN TURTR TKMTM TCATC UGAUG UKRUA " +
  "AREAE GBRGB USAUS URYUY UZBUZ VUTVU VENVE VNMVN YEMYE ZMBZM ZWEZW")
    .split(" ").map((pair) => [pair.slice(0, 3), pair.slice(3)])
);
const REGION_NAMES = new Intl.DisplayNames(["en"], {type: "region"});

export function countryLabel(storefront: string): string {
  const alpha2 = STOREFRONTS.get(storefront);
  if (alpha2 === undefined) return storefront;
  // 국기 이모지 = 두 글자를 Regional Indicator 문자로 옮긴 것.
  const flag = alpha2.replace(/[A-Z]/g, (c) => String.fromCodePoint(0x1f1a5 + c.charCodeAt(0)));
  return `${flag} ${REGION_NAMES.of(alpha2) ?? alpha2}`;
}

/**
 * 거래의 `price`는 **1000배 값**(milliunits)이다. 1000으로만 나눈다 — 엔·원은 소수점이 없어
 * 100으로 나누는 류의 실수가 바로 10배 오차로 나온다. 세금 포함·Apple 수수료 차감 전 금액이다.
 */
export function formatMoney(milliunits: number, currency: string): string {
  const amount = milliunits / 1000;
  const digits = Number.isInteger(amount) ? 0 : 2;
  const format = (currencyDisplay: "symbol" | "narrowSymbol"): string => new Intl.NumberFormat("en-US", {
    style: "currency", currency, currencyDisplay, minimumFractionDigits: digits, maximumFractionDigits: digits,
  }).format(amount);
  const symbol = format("symbol");
  if (!/^[A-Z]{3}/.test(symbol)) return symbol;
  // 세 글자 코드로 나오면 좁은 기호를 시도하되, 맨 "$"면 어느 나라 달러인지 사라지므로 코드를 남긴다.
  const narrow = format("narrowSymbol");
  return narrow.startsWith("$") ? symbol : narrow;
}

const OFFER_TYPES = new Map<number, string>([
  [1, "Introductory"], [2, "Promotional"], [3, "Offer code"], [4, "Win-back"],
]);

/** `offerIdentifier`는 App Store Connect에 등록한 오퍼 이름이지, 고객이 입력한 코드가 아니다. */
function offerLabel(tx: JWSTransactionDecodedPayload): string {
  if (tx.offerDiscountType === "FREE_TRIAL") return "Free trial";
  const type = tx.offerType === undefined ? undefined : OFFER_TYPES.get(tx.offerType);
  if (type === undefined) return "Full price";
  return tx.offerIdentifier ? `${type} · ${tx.offerIdentifier}` : type;
}

export interface NotificationFacts {
  headline: Headline;
  tx?: JWSTransactionDecodedPayload;
  renewal?: JWSRenewalInfoDecodedPayload;
  signedDate?: number;
  /** 원화 환산액. 원화 결제거나 환율을 못 받았으면 없다. */
  krw?: number;
  /** TestFlight·App Review·샌드박스 계정 결제. 실제 매출이 아니라 제목에 표시한다. */
  sandbox?: boolean;
}

interface SlackMessage {
  text: string;
  blocks: object[];
}

function rowsFor(facts: NotificationFacts): [string, string][] {
  const {headline, tx, renewal, signedDate} = facts;
  const rows: [string, string | undefined][] = [];
  if (tx?.productId) {
    // 다음 갱신 상품이 지금과 다르면 "어디서 → 어디로". 다운그레이드·해지 예약 직전 변경이 여기 걸린다.
    const next = renewal?.autoRenewProductId;
    rows.push(["Plan", next && next !== tx.productId ?
      `${planName(tx.productId)} → ${planName(next)}` : planName(tx.productId)]);
  }
  rows.push(["Country", tx?.storefront ? countryLabel(tx.storefront) : undefined]);
  if (headline.money && tx) rows.push(["Type", offerLabel(tx)]);
  // 가족 공유로 받은 권한은 그 사람이 낸 돈이 아니다. 평생 이용권도 가족 공유 때 ONE_TIME_CHARGE가 온다.
  if (tx?.inAppOwnershipType === InAppOwnershipType.FAMILY_SHARED) rows.push(["Owner", "Family Sharing"]);
  if (tx?.originalPurchaseDate && signedDate) {
    const days = Math.floor((signedDate - tx.originalPurchaseDate) / DAY_MS);
    if (days > 0) rows.push(["Tenure", `Day ${String(days)}`]);
  }
  // 누구인가 — Apple 계정(기기·상품 무관 하나), 이 구독 줄기.
  rows.push(["Account", tx?.appTransactionId]);
  rows.push(["Tx", tx?.originalTransactionId]);
  return rows.filter((row): row is [string, string] => row[1] !== undefined && row[1].length > 0);
}

/** 굵은 이름 + 한 세로선에 맞춘 값. 평범한 ``` 블록은 굵게가 안 먹어서 rich_text_preformatted를 쓴다. */
function boxBlock(rows: [string, string][]): object {
  const width = Math.max(...rows.map(([name]) => name.length)) + 3;
  const elements = rows.flatMap(([name, value], i) => [
    {type: "text", text: name.padEnd(width), style: {bold: true}},
    {type: "text", text: i === rows.length - 1 ? value : `${value}\n`},
  ]);
  return {type: "rich_text", elements: [{type: "rich_text_preformatted", elements}]};
}

export function messageFor(facts: NotificationFacts): SlackMessage {
  const {headline, tx, krw, sandbox} = facts;
  const price = tx?.price && tx.currency ? formatMoney(tx.price, tx.currency) : undefined;
  const amount = price && krw !== undefined ? `${price} (≈ ₩${krw.toLocaleString("en-US")})` : price;
  const tag = sandbox ? "   🧪 _Sandbox_" : "";
  const title = `${headline.mark} *${headline.title}*${amount ? `   ${amount}` : ""}${tag}`;
  const rows = rowsFor(facts);

  const blocks: object[] = [{type: "section", text: {type: "mrkdwn", text: title}}];
  if (rows.length > 0) blocks.push(boxBlock(rows));
  // 알림 미리보기용 한 줄.
  const preview = rows.filter(([name]) => name === "Plan" || name === "Country").map(([, value]) => value);
  const lead = [sandbox ? "🧪" : undefined, `${headline.mark} ${headline.title}`, amount].filter(Boolean).join(" ");
  const text = [lead, ...preview].join(" · ");
  return {text, blocks};
}

let krwRates: {fetchedMs: number; rates: Record<string, number>} | undefined;

/** 100원 단위. 원화 결제거나 환율을 못 받으면 undefined — 환산만 빼고 보낸다. */
async function toKrw(milliunits: number, currency: string): Promise<number | undefined> {
  if (currency === "KRW") return undefined;
  try {
    if (!krwRates || Date.now() - krwRates.fetchedMs > RATES_TTL_MS) {
      const response = await fetch(RATES_URL, {signal: AbortSignal.timeout(RATES_TIMEOUT_MS)});
      const body = await response.json() as {krw?: Record<string, number>};
      krwRates = {fetchedMs: Date.now(), rates: body.krw ?? {}};
    }
    const perKrw = krwRates.rates[currency.toLowerCase()];
    return perKrw ? Math.round(milliunits / 1000 / perKrw / 100) * 100 : undefined;
  } catch {
    return undefined;
  }
}

/**
 * 알림 하나를 슬랙에 보낸다. 시크릿이 없거나 보낼 종류가 아니면 아무것도 안 한다.
 *
 * 샌드박스 알림은 Trace와 달리 거르지 않고 🧪 표시로 보낸다. 받을지 말지는 App Store Connect의
 * Sandbox URL 칸으로 정한다 — 비워 두면 샌드박스 알림 자체가 여기로 오지 않는다.
 *
 * Apple 응답 **전에** 보낸다. 2세대 함수는 응답 뒤 CPU가 줄어 백그라운드 전송이 끊길 수 있다.
 * 대신 타임아웃을 짧게 둬 Apple 응답이 몇 초 넘게 밀리지 않게 한다.
 */
export async function postToSlack(payload: ResponseBodyV2DecodedPayload): Promise<void> {
  const url = process.env[SLACK_WEBHOOK_SECRET] ?? "";
  if (url.length === 0) return;
  if (!headlineFor(payload.notificationType, payload.subtype)) return;
  // notificationUUID 중복 제거 없음. 수신구가 늘 200을 돌려줘 Apple 재전송이 드물다 — 중복이 보이면 Firestore에 UUID를 남긴다.
  try {
    const signedTx = payload.data?.signedTransactionInfo;
    const signedRenewal = payload.data?.signedRenewalInfo;
    const tx = signedTx ? await decodeTransactionInfo(signedTx) : undefined;
    const headline = headlineFor(payload.notificationType, payload.subtype, tx);
    if (!headline) return;
    const renewal = signedRenewal ? await decodeRenewalInfo(signedRenewal) : undefined;
    const krw = tx?.price && tx.currency ? await toKrw(tx.price, tx.currency) : undefined;
    const message = messageFor({
      headline, tx, renewal, krw,
      signedDate: payload.signedDate,
      sandbox: payload.data?.environment === Environment.SANDBOX,
    });
    const response = await fetch(url, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(message),
      signal: AbortSignal.timeout(SLACK_TIMEOUT_MS),
    });
    if (!response.ok) logger.warn("⚠️ [appStore] 슬랙 전송 실패", {status: response.status});
  } catch (error) {
    logger.warn("⚠️ [appStore] 슬랙 전송 실패", error);
  }
}
