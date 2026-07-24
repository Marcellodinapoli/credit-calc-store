import * as admin from "firebase-admin";
import { DocumentData } from "firebase-admin/firestore";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";

import { contactEmail, NOTIFICATION_TYPES } from "./config";
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

  const targets = await loadProductNotificationTargets(target);
  await sendPushToTargets(targets, {
    title,
    body,
    type: NOTIFICATION_TYPES.ANNOUNCEMENT,
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
    if (beforeAt === afterAt) return;
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
