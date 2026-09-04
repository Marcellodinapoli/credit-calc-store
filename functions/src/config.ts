import { defineString } from "firebase-functions/params";

/**
 * Email di contatto / mittente di riferimento del progetto.
 * Per ora usa l'indirizzo predefinito Firebase; sostituire con email
 * personale impostando la variabile CONTACT_EMAIL al deploy:
 *   firebase functions:secrets:set CONTACT_EMAIL
 * oppure in Firebase Console → Functions → Environment variables.
 */
export const contactEmail = defineString("CONTACT_EMAIL", {
  default: "noreply@creditform-d505d.firebaseapp.com",
  description:
    "Email di riferimento progetto (sostituire con email personale quando disponibile)",
});

/** Secret condiviso Outfit → CreditCore per push assistenza admin. */
export const supportAdminBridgeSecret = defineString(
  "SUPPORT_ADMIN_BRIDGE_SECRET",
  {
    default: "outfit-creditcore-support-bridge-v1",
    description:
      "Secret HTTP per bridge push assistenza da progetto Outfit al BackOffice",
  },
);

export const NOTIFICATION_TYPES = {
  ANNOUNCEMENT: "announcement",
  JOB_OFFER: "job_offer",
  COURSE: "course",
  FIELD_VISIT: "field_visit",
  FIELD_REMINDER: "field_reminder",
  SUPPORT_MESSAGE: "support_message",
  SUPPORT_REPLY: "support_reply",
  COMMUNITY_MESSAGE: "community_message",
  ROLEPLAY: "roleplay",
} as const;

export type NotificationType =
  (typeof NOTIFICATION_TYPES)[keyof typeof NOTIFICATION_TYPES];
