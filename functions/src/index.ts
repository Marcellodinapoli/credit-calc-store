import * as admin from "firebase-admin";
import { DocumentData } from "firebase-admin/firestore";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";

import {
  contactEmail,
  NOTIFICATION_TYPES,
  supportAdminBridgeSecret,
} from "./config";
import { normativeSearch } from "./ai_normative_search";
import { callAnalysis } from "./ai_call_analysis";
import { roleplayStep } from "./ai_roleplay_step";
import { roleplaySuggestion } from "./ai_roleplay_suggestion";
import { roleplayRealtimeToken } from "./ai_roleplay_realtime_token";
import { trackRoleplayRealtimeUsage } from "./ai_roleplay_realtime_usage";
import { warmupEvaluate } from "./ai_warmup_evaluate";
import { contestationGenerate } from "./ai_contestation_generate";
import { getAiUsageStats } from "./ai_get_usage_stats";
import {
  db,
  formatDateTime,
  loadAdminDeviceTargets,
  loadItineraryTarget,
  loadJobSeekerTargets,
  loadProductNotificationTargets,
  sendPushToTargets,
  sendPushToUser,
} from "./notifications";

const region = "europe-west1";

function isPublishedJobOffer(data: DocumentData | undefined): boolean {
  return data?.status === "approved" && data?.online === true;
}

async function notifyAnnouncement(
  docId: string,
  data: DocumentData,
): Promise<void> {
  if (data.active !== true) return;

  const target = typeof data.target === "string" ? data.target : "all";
  const title = (data.title ?? "CreditCore").toString();
  const message = (data.message ?? "").toString();
  const body =
    message.length > 240 ? `${message.substring(0, 237)}...` : message ||
      "Nuovo aggiornamento disponibile";

  const targets = await loadProductNotificationTargets(
    // "all" → solo pubblici (richiesta prodotto); altri target restano filtrati.
    target === "all" ? "public" : target,
  );
  await sendPushToTargets(targets, {
    title,
    body,
    type: NOTIFICATION_TYPES.ANNOUNCEMENT,
    badge: 1,
    data: { announcementId: docId },
  });

  logger.info("Announcement push sent", {
    docId,
    target,
    recipients: targets.length,
    contactEmail: contactEmail.value(),
  });
}

export const onAnnouncementCreated = onDocumentCreated(
  { document: "announcements/{docId}", region },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    await notifyAnnouncement(event.params.docId, data);
  },
);

export const onAnnouncementUpdated = onDocumentUpdated(
  { document: "announcements/{docId}", region },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after) return;

    const wasActive = before?.active === true;
    const isActive = after.active === true;
    if (wasActive || !isActive) return;

    await notifyAnnouncement(event.params.docId, after);
  },
);

export const onCourseCreated = onDocumentCreated(
  { document: "courses/{courseId}", region },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const title = (data.title ?? "Nuovo corso").toString();
    const targets = await loadProductNotificationTargets();
    await sendPushToTargets(targets, {
      title: "Nuovo corso su CreditForm",
      body: title,
      type: NOTIFICATION_TYPES.COURSE,
      badge: 1,
      data: { courseId: event.params.courseId },
    });

    logger.info("Course push sent", {
      courseId: event.params.courseId,
      recipients: targets.length,
    });
  },
);

export const onJobOfferPublished = onDocumentUpdated(
  { document: "job_offers/{offerId}", region },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after) return;

    if (isPublishedJobOffer(before) || !isPublishedJobOffer(after)) return;

    const title = (after.title ?? "Offerta di lavoro").toString();
    const targets = await loadJobSeekerTargets();
    await sendPushToTargets(targets, {
      title: "Nuova offerta su CreditJob",
      body: title,
      type: NOTIFICATION_TYPES.JOB_OFFER,
      data: { offerId: event.params.offerId },
    });

    logger.info("Job offer push sent", {
      offerId: event.params.offerId,
      recipients: targets.length,
    });
  },
);

/** Messaggio su Assistenza diretta → push admin (user) o badge utente (admin). */
export const onSupportUserMessageCreated = onDocumentCreated(
  { document: "support/{ticketId}/messages/{messageId}", region },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const ticketId = event.params.ticketId;
    const ticketSnap = await db.collection("support").doc(ticketId).get();
    const ticket = ticketSnap.data() ?? {};
    const subject = (ticket.subject ?? "Assistenza diretta").toString().trim();
    const text = (data.text ?? "").toString().trim();
    const body =
      text.length > 0
        ? text.length > 160
          ? `${text.substring(0, 157)}...`
          : text
        : "Nuovo messaggio di supporto";
    const sender = (data.sender ?? "").toString();

    if (sender === "user") {
      const targets = await loadAdminDeviceTargets();
      await sendPushToTargets(targets, {
        title: subject || "Assistenza diretta",
        body,
        type: NOTIFICATION_TYPES.SUPPORT_MESSAGE,
        badge: 1,
        data: {
          ticketId,
          messageId: event.params.messageId,
        },
      });
      logger.info("Support message push sent", {
        ticketId,
        recipients: targets.length,
      });
      return;
    }

    // Risposta admin → badge icona utente CreditCalc.
    const userId = (ticket.userId ?? "").toString().trim();
    if (!userId) return;
    await sendPushToUser(userId, {
      title: subject || "Assistenza diretta",
      body,
      type: NOTIFICATION_TYPES.SUPPORT_REPLY,
      badge: 1,
      data: {
        ticketId,
        messageId: event.params.messageId,
      },
    });
    logger.info("Support reply push sent", { ticketId, userId });
  },
);

/** Nuovo messaggio community → badge al creatore del topic (se non è l'autore). */
export const onCommunityMessageCreated = onDocumentCreated(
  { document: "community/{topicId}/messages/{messageId}", region },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const senderId = (data.userId ?? "").toString().trim();
    if (!senderId) return;

    const topicId = event.params.topicId;
    const topicSnap = await db.collection("community").doc(topicId).get();
    const topic = topicSnap.data();
    if (!topic || topic.status !== "approved") return;

    const ownerId = (topic.userId ?? "").toString().trim();
    if (!ownerId || ownerId === senderId) return;

    const text = (data.text ?? data.message ?? "").toString().trim();
    const body =
      text.length > 0
        ? text.length > 160
          ? `${text.substring(0, 157)}...`
          : text
        : "Nuova risposta in community";
    const title = (topic.title ?? "Community").toString().trim() || "Community";

    await sendPushToUser(ownerId, {
      title,
      body,
      type: NOTIFICATION_TYPES.COMMUNITY_MESSAGE,
      badge: 1,
      data: {
        topicId,
        messageId: event.params.messageId,
      },
    });
    logger.info("Community reply push sent", { topicId, ownerId });
  },
);

/** Nuovo roleplay → badge utenti con notifiche prodotto. */
export const onRoleplayCreated = onDocumentCreated(
  { document: "roleplay/{roleplayId}", region },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const title =
      (data.title ?? data.name ?? "Nuova simulazione roleplay").toString();
    const targets = await loadProductNotificationTargets();
    await sendPushToTargets(targets, {
      title: "Nuovo Role Play",
      body: title,
      type: NOTIFICATION_TYPES.ROLEPLAY,
      badge: 1,
      data: { roleplayId: event.params.roleplayId },
    });
    logger.info("Roleplay push sent", {
      roleplayId: event.params.roleplayId,
      recipients: targets.length,
    });
  },
);

/**
 * Bridge da progetto Outfit: stesso push/badge admin senza token FCM Outfit.
 * Header: x-support-bridge-secret
 * Body JSON: { title?, body?, ticketId?, messageId? }
 */
export const notifyAdminSupportBridge = onRequest(
  { region, cors: false },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const secret = (req.get("x-support-bridge-secret") || "").trim();
    if (!secret || secret !== supportAdminBridgeSecret.value()) {
      res.status(403).send("Forbidden");
      return;
    }

    const body = (req.body ?? {}) as Record<string, unknown>;
    const title =
      typeof body.title === "string" && body.title.trim()
        ? body.title.trim()
        : "Assistenza MOODFIT";
    const text =
      typeof body.body === "string" ? body.body.trim() : "Nuovo messaggio di supporto";
    const ticketId =
      typeof body.ticketId === "string" ? body.ticketId.trim() : "";
    const messageId =
      typeof body.messageId === "string" ? body.messageId.trim() : "";

    const targets = await loadAdminDeviceTargets();
    await sendPushToTargets(targets, {
      title,
      body: text,
      type: NOTIFICATION_TYPES.SUPPORT_MESSAGE,
      badge: 1,
      data: {
        source: "outfit",
        ticketId,
        messageId,
      },
    });

    logger.info("Outfit support bridge push sent", {
      ticketId,
      recipients: targets.length,
    });
    res.status(200).json({ ok: true, recipients: targets.length });
  },
);

export const scheduledItineraryPushes = onSchedule(
  {
    schedule: "every 10 minutes",
    timeZone: "Europe/Rome",
    region,
  },
  async () => {
    await sendPreVisitPushes();
    await sendReminderPushes();
  },
);

async function sendPreVisitPushes(): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  const minTime = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + 25 * 60 * 1000,
  );
  const maxTime = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + 35 * 60 * 1000,
  );

  const snap = await db
    .collection("field_visits")
    .where("preVisitPushSent", "==", false)
    .where("scheduledAt", ">=", minTime)
    .where("scheduledAt", "<=", maxTime)
    .get();

  for (const doc of snap.docs) {
    const data = doc.data();
    if (data.status !== "planned") continue;

    const userId = (data.userId ?? "").toString();
    if (!userId) continue;

    const target = await loadItineraryTarget(userId);
    if (!target) continue;

    const company = (data.companyName ?? "Visita in programma").toString().trim();
    const address = (data.address ?? "").toString().trim();
    const scheduledAt = data.scheduledAt as admin.firestore.Timestamp;
    const timeLabel = formatDateTime(scheduledAt);
    const body = address
      ? `${address} · ${timeLabel}`
      : `Appuntamento alle ${timeLabel}`;

    await sendPushToTargets([target], {
      title: company || "Visita in programma",
      body,
      type: NOTIFICATION_TYPES.FIELD_VISIT,
      data: { visitId: doc.id },
    });

    await doc.ref.update({
      preVisitPushSent: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

async function sendReminderPushes(): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  const minTime = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + 2 * 60 * 1000,
  );
  const maxTime = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + 8 * 60 * 1000,
  );

  const snap = await db
    .collection("field_reminders")
    .where("pushSent", "==", false)
    .where("remindAt", ">=", minTime)
    .where("remindAt", "<=", maxTime)
    .get();

  for (const doc of snap.docs) {
    const data = doc.data();
    if ((data.status ?? "planned") !== "planned") continue;

    const userId = (data.userId ?? "").toString();
    if (!userId) continue;

    const target = await loadItineraryTarget(userId);
    if (!target) continue;

    const title = (data.title ?? "Promemoria itinerario").toString().trim();
    const notes = (data.notes ?? "").toString().trim();
    const remindAt = data.remindAt as admin.firestore.Timestamp;
    const timeLabel = formatDateTime(remindAt);
    const body = notes ? `${notes} · ${timeLabel}` : timeLabel;

    await sendPushToTargets([target], {
      title,
      body,
      type: NOTIFICATION_TYPES.FIELD_REMINDER,
      data: { reminderId: doc.id },
    });

    await doc.ref.update({
      pushSent: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

export const onFieldVisitRescheduled = onDocumentUpdated(
  { document: "field_visits/{visitId}", region },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const beforeAt = before.scheduledAt?.toMillis?.() ?? 0;
    const afterAt = after.scheduledAt?.toMillis?.() ?? 0;
    const statusChanged = before.status !== after.status;

    if (!statusChanged && beforeAt === afterAt) return;
    if (after.preVisitPushSent === false) return;

    await event.data?.after.ref.update({
      preVisitPushSent: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  },
);

export const onFieldReminderRescheduled = onDocumentUpdated(
  { document: "field_reminders/{reminderId}", region },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const beforeAt = before.remindAt?.toMillis?.() ?? 0;
    const afterAt = after.remindAt?.toMillis?.() ?? 0;
    const statusChanged = before.status !== after.status;

    if (!statusChanged && beforeAt === afterAt) return;
    if (after.pushSent === false) return;

    await event.data?.after.ref.update({
      pushSent: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  },
);

// Esportato per test/manutenzione: invio singolo a utente con preferenze attive.
export {
  sendPushToUser,
  normativeSearch,
  callAnalysis,
  roleplayStep,
  roleplaySuggestion,
  roleplayRealtimeToken,
  trackRoleplayRealtimeUsage,
  warmupEvaluate,
  contestationGenerate,
  getAiUsageStats,
};
