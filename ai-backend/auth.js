import admin from "firebase-admin";

import { config } from "./config.js";

let initialized = false;

export function initFirebaseAuth() {
  if (initialized || admin.apps.length > 0) {
    initialized = true;
    return;
  }

  const { projectId, clientEmail, privateKey } = config.firebase;

  if (!projectId || !clientEmail || !privateKey) {
    console.warn(
      "Firebase Auth non configurato: imposta FIREBASE_PROJECT_ID, " +
        "FIREBASE_CLIENT_EMAIL e FIREBASE_PRIVATE_KEY.",
    );
    return;
  }

  admin.initializeApp({
    credential: admin.credential.cert({
      projectId,
      clientEmail,
      privateKey,
    }),
  });

  initialized = true;
}

export async function verifyAuthToken(token) {
  if (!config.requireAuth) {
    return { uid: "anonymous" };
  }

  if (!token || typeof token !== "string") {
    throw new Error("Token di autenticazione mancante.");
  }

  initFirebaseAuth();

  if (!admin.apps.length) {
    throw new Error("Firebase Auth non configurato sul proxy Realtime.");
  }

  const decoded = await admin.auth().verifyIdToken(token);
  return { uid: decoded.uid };
}
