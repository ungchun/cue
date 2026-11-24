/**
 * App Store 서명 검증. Trace(functions/src/appStore.ts)의 검증기 부분만 옮겼다.
 *
 * 검증은 Apple 공식 라이브러리에 맡긴다. JWS의 x5c 사슬을 Apple Root CA - G3까지 직접 타는
 * 코드를 손으로 쓰면 틀렸을 때 조용히 통과한다 — 수신 URL은 공개 주소라 아무나 가짜 "환불"을 보낼 수 있다.
 */
import {readFileSync} from "fs";
import {join} from "path";
import * as logger from "firebase-functions/logger";
import {
  SignedDataVerifier,
  Environment,
  JWSTransactionDecodedPayload,
  JWSRenewalInfoDecodedPayload,
  ResponseBodyV2DecodedPayload,
} from "@apple/app-store-server-library";

const BUNDLE_ID = "azhy.cue";
/**
 * App Store의 앱 id. 운영 환경 검증에 반드시 필요하고, 비밀이 아니다(스토어 URL에 그대로 있다 —
 * 앱의 `SupportLinks.appStoreID`와 같은 값).
 */
const APP_APPLE_ID = 6789932436;

let verifiers: SignedDataVerifier[] | undefined;

/**
 * 운영과 샌드박스를 모두 준비하고 운영부터 시도한다. TestFlight·App Review 결제는 샌드박스로 온다.
 * 인증서는 처음 검증할 때 읽는다 — 순수 함수만 쓰는 테스트가 파일을 요구하지 않게.
 */
function allVerifiers(): SignedDataVerifier[] {
  if (!verifiers) {
    const roots = [readFileSync(join(__dirname, "..", "certs", "AppleRootCA-G3.cer"))];
    verifiers = [Environment.PRODUCTION, Environment.SANDBOX].map((env) =>
      // 온라인 OCSP 확인은 끈다 — 실행 시간에 Apple CA 응답 시간이 얹힌다. 사슬 검증 자체는 그대로 돈다.
      new SignedDataVerifier(roots, false, env, BUNDLE_ID, APP_APPLE_ID));
  }
  return verifiers;
}

async function firstVerified<T>(decode: (verifier: SignedDataVerifier) => Promise<T>): Promise<T | undefined> {
  for (const verifier of allVerifiers()) {
    try {
      return await decode(verifier);
    } catch {
      // 다음 환경
    }
  }
  return undefined;
}

/** Apple 서명이 아니거나 번들이 다르면 undefined. 던지지 않는다. */
export async function verifyNotification(
  signedPayload: string
): Promise<ResponseBodyV2DecodedPayload | undefined> {
  const payload = await firstVerified((verifier) => verifier.verifyAndDecodeNotification(signedPayload));
  if (!payload) logger.warn("⚠️ [appStore] 검증 실패한 알림을 버린다");
  return payload;
}

export async function decodeTransactionInfo(signed: string): Promise<JWSTransactionDecodedPayload | undefined> {
  return firstVerified((verifier) => verifier.verifyAndDecodeTransaction(signed));
}

export async function decodeRenewalInfo(signed: string): Promise<JWSRenewalInfoDecodedPayload | undefined> {
  return firstVerified((verifier) => verifier.verifyAndDecodeRenewalInfo(signed));
}
