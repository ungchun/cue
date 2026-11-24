import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {verifyNotification} from "./appStore";
import {postToSlack, SLACK_WEBHOOK_SECRET} from "./appStoreSlack";

setGlobalOptions({maxInstances: 3});

/**
 * App Store Server Notifications V2 수신구. 하는 일은 하나 — 검증한 알림을 슬랙에 띄운다.
 *
 * 앱은 이 함수와 통신하지 않는다. Apple 서버 → 이 함수 → 슬랙 웹훅. 환불·갱신·해지는 기기 밖에서
 * 일어나 앱이 알 수 없으므로, Apple이 보내주는 이 알림이 유일한 출처다.
 *
 * App Store Connect → 앱 → 앱 정보 → App Store Server Notifications에 이 함수 URL을 등록한다(Version 2).
 */
export const appStoreNotifications = onRequest({
  secrets: [SLACK_WEBHOOK_SECRET],
  timeoutSeconds: 30,
  memory: "256MiB",
}, async (req, res) => {
  try {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }
    const signedPayload = (req.body as {signedPayload?: unknown} | undefined)?.signedPayload;
    if (typeof signedPayload !== "string" || signedPayload.length === 0) {
      res.status(400).send("bad payload");
      return;
    }

    const payload = await verifyNotification(signedPayload);
    if (!payload) {
      // Apple 서명이 아니다 — 위조이거나 번들이 다르다. 슬랙에 아무것도 띄우지 않는다.
      res.status(401).send("unverified");
      return;
    }

    logger.info("📬 [appStore] 알림", {
      type: payload.notificationType ?? null,
      subtype: payload.subtype ?? null,
      environment: payload.data?.environment ?? null,
    });
    await postToSlack(payload);
    res.status(200).send("ok");
  } catch (error) {
    logger.error("❌ [appStoreNotifications] Error:", error);
    // 5xx를 주면 Apple이 재시도한다. 우리 버그로 무한 재시도를 부르지 않도록 200으로 닫는다.
    res.status(200).send("ok");
  }
});
