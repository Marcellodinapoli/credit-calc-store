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

export const NOTIFICATION_TYPES = {
  ANNOUNCEMENT: "announcement",
  JOB_OFFER: "job_offer",
  COURSE: "course",
  FIELD_VISIT: "field_visit",
  FIELD_REMINDER: "field_reminder",
} as const;

export type NotificationType =
  (typeof NOTIFICATION_TYPES)[keyof typeof NOTIFICATION_TYPES];
