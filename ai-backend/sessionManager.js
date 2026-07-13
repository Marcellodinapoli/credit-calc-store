import { config } from "./config.js";

/** @type {Map<string, object>} */
const sessions = new Map();

export function createSession({
  sessionId,
  userId = null,
  provider = "realtime",
}) {
  const now = Date.now();
  const session = {
    sessionId,
    userId,
    provider,
    callState: "connecting",
    history: [],
    createdAt: now,
    updatedAt: now,
    lastHeartbeatAt: now,
  };
  sessions.set(sessionId, session);
  return session;
}

export function getSession(sessionId) {
  return sessions.get(sessionId) || null;
}

export function touchSession(sessionId, patch = {}) {
  const session = sessions.get(sessionId);
  if (!session) return null;
  Object.assign(session, patch, { updatedAt: Date.now() });
  return session;
}

export function touchHeartbeat(sessionId) {
  const session = sessions.get(sessionId);
  if (!session) return null;
  session.lastHeartbeatAt = Date.now();
  session.updatedAt = Date.now();
  return session;
}

export function appendHistory(sessionId, role, content) {
  const session = sessions.get(sessionId);
  if (!session || !content?.trim()) return null;

  session.history.push({ role, content: content.trim() });
  if (session.history.length > 40) {
    session.history.splice(0, session.history.length - 40);
  }
  session.updatedAt = Date.now();
  return session;
}

export function closeSession(sessionId) {
  const session = sessions.get(sessionId);
  if (!session) return;
  session.callState = "closed";
  session.updatedAt = Date.now();
}

export function cleanupExpiredSessions() {
  const now = Date.now();
  for (const [id, session] of sessions.entries()) {
    if (now - session.updatedAt > config.sessionTimeoutMs) {
      sessions.delete(id);
    }
  }
}

setInterval(cleanupExpiredSessions, 60 * 1000);
