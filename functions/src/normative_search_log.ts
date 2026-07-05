import * as admin from "firebase-admin";

const COLLECTION = "normative_search_logs";
const MAX_QUESTION = 2000;
const MAX_ANSWER = 12000;
const MAX_PREVIEW = 300;

export async function recordNormativeSearchLog(params: {
  userId: string;
  userEmail?: string | null;
  question: string;
  answer: string;
  inputTokens?: number;
  outputTokens?: number;
}): Promise<void> {
  const question = params.question.slice(0, MAX_QUESTION);
  const answer = params.answer.slice(0, MAX_ANSWER);

  await admin.firestore().collection(COLLECTION).add({
    userId: params.userId,
    userEmail: params.userEmail ?? null,
    question,
    answer,
    answerPreview: answer.slice(0, MAX_PREVIEW),
    inputTokens: Math.max(0, params.inputTokens ?? 0),
    outputTokens: Math.max(0, params.outputTokens ?? 0),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

export function trackNormativeSearchLog(params: {
  userId: string;
  userEmail?: string | null;
  question: string;
  answer: string;
  inputTokens?: number;
  outputTokens?: number;
}): void {
  recordNormativeSearchLog(params).catch((error) => {
    console.error("Normative search log failed:", error);
  });
}
