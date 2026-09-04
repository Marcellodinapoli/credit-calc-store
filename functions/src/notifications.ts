import * as admin from "firebase-admin";
import { MulticastMessage } from "firebase-admin/messaging";

import { NotificationType } from "./config";

admin.initializeApp();

export const db = admin.firestore();
export const messaging = admin.messaging();

const FCM_BATCH_SIZE = 500;

export interface UserPushTarget {
  uid: string;
  token: string;
}

export interface PushPayload {
  title: string;
  body: string;
  type: NotificationType;
  data?: Record<string, string>;
  /** Se impostato, aggiorna il badge sull'icona (iOS / launcher Android). */
  badge?: number;
}

function isInvalidTokenError(code: string | undefined): boolean {
  return (
    code === "messaging/invalid-registration-token" ||
    code === "messaging/registration-token-not-registered"
  );
}

async function clearInvalidToken(uid: string): Promise<void> {
  await db.collection("users").doc(uid).set(
    {
      fcmToken: admin.firestore.FieldValue.delete(),
      pushPlatform: admin.firestore.FieldValue.delete(),
      productNotificationsUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

export async function loadProductNotificationTargets(
  targetFilter?: string,
): Promise<UserPushTarget[]> {
  const snap = await db
    .collection("users")
    .where("productNotificationsEnabled", "==", true)
    .get();

  const targets: UserPushTarget[] = [];
  for (const doc of snap.docs) {
    const data = doc.data();
    const token = typeof data.fcmToken === "string" ? data.fcmToken.trim() : "";
    if (!token) continue;

    if (data.pushPlatform === "windows") continue;

    const userType = normalizeUserType(data.type);
    if (targetFilter && targetFilter !== "all" && userType !== targetFilter) {
      continue;
    }

    targets.push({ uid: doc.id, token });
  }
  return targets;
}

export async function loadJobSeekerTargets(): Promise<UserPushTarget[]> {
  const snap = await db
    .collection("users")
    .where("productNotificationsEnabled", "==", true)
    .get();

  const targets: UserPushTarget[] = [];
  for (const doc of snap.docs) {
    const data = doc.data();
    const token = typeof data.fcmToken === "string" ? data.fcmToken.trim() : "";
    if (!token || data.pushPlatform === "windows") continue;

    const userType = normalizeUserType(data.type);
    if (userType === "company") continue;

    targets.push({ uid: doc.id, token });
  }
  return targets;
}

export async function loadItineraryTarget(
  userId: string,
): Promise<UserPushTarget | null> {
  const doc = await db.collection("users").doc(userId).get();
  if (!doc.exists) return null;

  const data = doc.data() ?? {};
  if (data.productNotificationsEnabled !== true) return null;
  if (data.itineraryNotificationsEnabled !== true) return null;

  const token = typeof data.fcmToken === "string" ? data.fcmToken.trim() : "";
  if (!token || data.pushPlatform === "windows") return null;

  return { uid: doc.id, token };
}

/** Token FCM del BackOffice Admin (devices + security_devices legacy). */
export async function loadAdminDeviceTargets(): Promise<UserPushTarget[]> {
  const targets: UserPushTarget[] = [];
  const seen = new Set<string>();

  const addToken = (docId: string, raw: unknown) => {
    const token = typeof raw === "string" ? raw.trim() : "";
    if (!token || seen.has(token)) return;
    seen.add(token);
    targets.push({ uid: docId, token });
  };

  const devicesSnap = await db.collection("devices").get();
  for (const doc of devicesSnap.docs) {
    addToken(doc.id, doc.data().token);
  }

  const securitySnap = await db.collection("security_devices").get();
  for (const doc of securitySnap.docs) {
    addToken(`security:${doc.id}`, doc.data().token);
  }

  return targets;
}

async function clearInvalidDeviceToken(deviceDocId: string): Promise<void> {
  if (deviceDocId.startsWith("security:")) {
    // Non cancellare security_devices/admin_device: usato anche per login.
    return;
  }
  await db.collection("devices").doc(deviceDocId).delete().catch(() => undefined);
}

export function normalizeUserType(value: unknown): string {
  const raw = typeof value === "string" ? value.trim() : "";
  return raw.length > 0 ? raw : "public";
}

export async function sendPushToTargets(
  targets: UserPushTarget[],
  payload: PushPayload,
): Promise<void> {
  if (targets.length === 0) return;

  const data: Record<string, string> = {
    type: payload.type,
    click_action: "FLUTTER_NOTIFICATION_CLICK",
    ...payload.data,
  };

  for (let i = 0; i < targets.length; i += FCM_BATCH_SIZE) {
    const chunk = targets.slice(i, i + FCM_BATCH_SIZE);
    const tokens = chunk.map((t) => t.token);

    const channelId =
      payload.type === "field_visit" || payload.type === "field_reminder"
        ? "creditcore_itinerary"
        : payload.type === "support_message" ||
            payload.type === "support_reply" ||
            payload.type === "community_message"
          ? "creditcore_support"
          : "creditcore_product";

    const message: MulticastMessage = {
      tokens,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data,
      android: {
        priority: "high",
        notification: {
          channelId,
          ...(payload.badge != null
            ? { notificationCount: payload.badge, defaultSound: true }
            : {}),
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            ...(payload.badge != null ? { badge: payload.badge } : {}),
            alert: {
              title: payload.title,
              body: payload.body,
            },
          },
        },
      },
    };

    const response = await messaging.sendEachForMulticast(message);
    response.responses.forEach((result, index) => {
      if (result.success) return;
      const errorCode = result.error?.code;
      if (!isInvalidTokenError(errorCode)) return;
      const target = chunk[index];
      if (payload.type === "support_message") {
        void clearInvalidDeviceToken(target.uid);
      } else {
        void clearInvalidToken(target.uid);
      }
    });
  }
}

export async function sendPushToUser(
  userId: string,
  payload: PushPayload,
): Promise<boolean> {
  const doc = await db.collection("users").doc(userId).get();
  const data = doc.data() ?? {};
  if (data.productNotificationsEnabled !== true) {
    loggerWarnNoToken(userId, "productNotificationsEnabled!=true");
    return false;
  }
  const token = typeof data.fcmToken === "string" ? data.fcmToken.trim() : "";
  if (!token || data.pushPlatform === "windows") {
    loggerWarnNoToken(userId, "missing-fcmToken-or-windows");
    return false;
  }
  await sendPushToTargets([{ uid: userId, token }], payload);
  return true;
}

function loggerWarnNoToken(userId: string, reason: string): void {
  // Evita import circolare di logger: console va bene in CF.
  console.warn(`[sendPushToUser] skip ${userId}: ${reason}`);
}

export function formatDateTime(value: admin.firestore.Timestamp): string {
  const date = value.toDate();
  const d = date.getDate().toString().padStart(2, "0");
  const m = (date.getMonth() + 1).toString().padStart(2, "0");
  const h = date.getHours().toString().padStart(2, "0");
  const min = date.getMinutes().toString().padStart(2, "0");
  return `${d}/${m}/${date.getFullYear()} ${h}:${min}`;
}
