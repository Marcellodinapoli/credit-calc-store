import { onCall, HttpsError } from "firebase-functions/v2/https";



import {

  estimateWhisperSecondsFromBytes,

  trackAiUsage,

} from "./ai_usage_tracker";

import { callOpenAiChat, OPENAI_MODEL_GPT_55, openAiApiKey } from "./openai";



const region = "europe-west1";



async function transcribeAudio(

  base64Audio: string,

  mimeType: string,

): Promise<{ text: string; whisperSeconds: number }> {

  const apiKey = openAiApiKey.value()?.trim();

  if (!apiKey) {

    throw new HttpsError(

      "failed-precondition",

      "API OpenAI non configurata.",

    );

  }



  const buffer = Buffer.from(base64Audio, "base64");

  if (buffer.length < 1000) {

    throw new HttpsError("invalid-argument", "Registrazione troppo breve.");

  }



  const whisperSeconds = estimateWhisperSecondsFromBytes(buffer.length);

  const extension = mimeType.includes("wav") ? "wav" : "m4a";

  const blob = new Blob([buffer], { type: mimeType || "audio/m4a" });

  const form = new FormData();

  form.append("file", blob, `recording.${extension}`);

  form.append("model", "whisper-1");

  form.append("language", "it");



  const response = await fetch("https://api.openai.com/v1/audio/transcriptions", {

    method: "POST",

    headers: { Authorization: `Bearer ${apiKey}` },

    body: form,

  });



  if (!response.ok) {

    console.error("Whisper error:", response.status, await response.text());

    throw new HttpsError("internal", "Impossibile trascrivere l'audio.");

  }



  const payload = (await response.json()) as { text?: string };

  return {

    text: (payload.text ?? "").trim(),

    whisperSeconds,

  };

}



async function evaluateTranscript(params: {

  transcript: string;

  phase: string;

  expectedText: string;

  phaseExplanation: string;

  customerLine: string;

  kind?: "warmup" | "contestation";

}): Promise<{ commento: string; versione_migliorata: string; usage: {

  promptTokens: number;

  completionTokens: number;

} }> {

  const systemPrompt =

    params.kind === "contestation"

      ? "Sei un formatore esperto in recupero crediti e gestione contestazioni "

        + "telefoniche in Italia. Valuta la risposta vocale dell'operatore rispetto "

        + "al contesto e alla linea corretta. Rispondi SOLO in JSON con due campi: "

        + "commento (feedback breve e costruttivo in italiano) e versione_migliorata "

        + "(esempio di risposta vocale migliorata, 2-4 frasi)."

      : "Sei un formatore esperto in recupero crediti e warm-up telefonico "

        + "in Italia. Valuta la risposta vocale dell'operatore rispetto "

        + "al contesto e alla linea corretta. Rispondi SOLO in JSON con due campi: "

        + "commento (feedback breve e costruttivo in italiano) e versione_migliorata "

        + "(esempio di risposta vocale migliorata, 2-4 frasi).";



  const userPrompt = [

    params.phase === "Approccio"
      ? "IMPORTANTE: in fase Approccio l'operatore NON deve presentarsi "
        + "(no nome, cognome, società). Valuta solo se verifica l'identità "
        + "del debitore.\n"
      : params.phase === "Presentazione standard"
        ? "IMPORTANTE: in fase Presentazione standard l'operatore deve SOLO "
          + "presentarsi (nome, cognome, società mandante). NON deve parlare "
          + "di insoluti, debiti, scadenze, comunicazioni amministrative o "
          + "motivo del contatto. NON penalizzare l'assenza del motivo del "
          + "contatto: in questa fase non serve. Segnala come errore qualsiasi "
          + "riferimento al debito. Nell'esempio (versione_migliorata) proponi "
          + "solo una presentazione breve, senza motivo del contatto.\n"
        : params.phase === "Presentazione privacy"
          ? "IMPORTANTE: in fase Presentazione privacy l'operatore NON deve "
            + "dire per conto di chi chiama (no società mandante). Può indicare "
            + "al massimo nome e cognome. Deve chiedere un recapito telefonico "
            + "oppure farsi richiamare dal debitore, senza divulgare informazioni "
            + "sensibili a terzi. Nell'esempio (versione_migliorata) non includere "
            + "riferimenti alla società, al debito o al motivo della chiamata.\n"
          : params.phase === "Negoziazione"
            ? "IMPORTANTE: in fase Negoziazione l'esempio (versione_migliorata) "
              + "deve riportare 224 euro complessivi (200 euro di debito + 24 euro "
              + "di spese) e richiedere il pagamento entro oggi o al massimo domani "
              + "con tono fermo. NON usare domande tipo 'Può procedere con bonifico?': "
              + "deve essere una richiesta diretta di pagamento, non un'interrogativa.\n"
            : params.phase === "Chiusura"
              ? "IMPORTANTE: in fase Chiusura il commento deve prima ricordare "
                + "all'operatore l'obiettivo (ribadire impegno di 224 euro, rata "
                + "piu spese, pagamento entro domani, conferma e saluto). "
                + "Nell'esempio (versione_migliorata) usa 'domani' senza data "
                + "numerica (no 15/06, no 16/05). Riporta 224 euro complessivi.\n"
              : "",

    `Contesto: ${params.phaseExplanation}`,

    `Contestatione del cliente: ${params.customerLine}`,

    `Fase: ${params.phase}`,

    `Linea di risposta corretta (riferimento): ${params.expectedText}`,

    "",

    `Trascrizione risposta operatore: ${params.transcript}`,

  ].join("\n");



  const result = await callOpenAiChat(

    [

      { role: "system", content: systemPrompt },

      { role: "user", content: userPrompt },

    ],

    {

      temperature: 0.4,

      responseFormat: { type: "json_object" },

      model: OPENAI_MODEL_GPT_55,

    },

  );



  let parsed: { commento?: string; versione_migliorata?: string };

  try {

    parsed = JSON.parse(result.content);

  } catch (_) {

    parsed = { commento: result.content, versione_migliorata: "" };

  }



  return {

    commento: (parsed.commento ?? "").toString().trim(),

    versione_migliorata: (parsed.versione_migliorata ?? "").toString().trim(),

    usage: {

      promptTokens: result.usage.promptTokens,

      completionTokens: result.usage.completionTokens,

    },

  };

}



export const warmupEvaluate = onCall(

  { region, secrets: [openAiApiKey], timeoutSeconds: 120 },

  async (request) => {

    if (!request.auth) {

      throw new HttpsError(

        "unauthenticated",

        "Accesso richiesto per la valutazione warm-up.",

      );

    }



    const audioBase64 = (request.data?.audioBase64 ?? "").toString().trim();

    const mimeType = (request.data?.mimeType ?? "audio/m4a").toString();

    const phase = (request.data?.phase ?? "").toString().trim();

    const expectedText = (request.data?.expectedText ?? "").toString().trim();

    const phaseExplanation = (request.data?.phaseExplanation ?? "").toString().trim();

    const customerLine = (request.data?.customerLine ?? "").toString().trim();
    const kindRaw = (request.data?.kind ?? "warmup").toString().trim().toLowerCase();
    const kind = kindRaw === "contestation" ? "contestation" : "warmup";



    if (!audioBase64) {

      throw new HttpsError("invalid-argument", "Audio mancante.");

    }

    if (!expectedText) {

      throw new HttpsError("invalid-argument", "Riferimento risposta mancante.");

    }



    const transcription = await transcribeAudio(audioBase64, mimeType);

    if (!transcription.text) {

      throw new HttpsError(

        "invalid-argument",

        "Non è stato possibile capire l'audio. Riprova parlando più chiaramente.",

      );

    }



    const evaluation = await evaluateTranscript({

      transcript: transcription.text,

      phase,

      expectedText,

      phaseExplanation,

      customerLine,

      kind,

    });



    trackAiUsage({

      feature: "warmupEvaluate",

      inputTokens: evaluation.usage.promptTokens,

      outputTokens: evaluation.usage.completionTokens,

      whisperSeconds: transcription.whisperSeconds,

    });



    return {

      trascrizione: transcription.text,

      commento: evaluation.commento,

      versione_migliorata: evaluation.versione_migliorata,

    };

  },

);

