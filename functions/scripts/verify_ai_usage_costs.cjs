/**
 * Verifica che estimateCostUsd coincida col listino OpenAI ufficiale
 * su payload usage reali (Chat + Realtime + Whisper).
 *
 * Uso:
 *   node scripts/verify_ai_usage_costs.mjs
 *
 * Live (opzionale, richiede OPENAI_API_KEY):
 *   node scripts/verify_ai_usage_costs.mjs --live
 */
const path = require("path");
const fs = require("fs");

// Carica il modulo compilato (dopo npm run build).
const trackerPath = path.join(__dirname, "..", "lib", "ai_usage_tracker.js");
if (!fs.existsSync(trackerPath)) {
  console.error("Manca lib/ai_usage_tracker.js — esegui prima: npm run build");
  process.exit(1);
}

const {
  estimateCostUsd,
  modalityFromRealtimeUsage,
} = require(trackerPath);

const USD_EPS = 1e-9;

function assertClose(actual, expected, label) {
  const ok = Math.abs(actual - expected) < 1e-6 + USD_EPS;
  if (!ok) {
    console.error(`FAIL ${label}: got ${actual}, expected ${expected}`);
    process.exitCode = 1;
  } else {
    console.log(`OK   ${label}: ${actual}`);
  }
}

function perM(tokens, rate) {
  return (tokens / 1_000_000) * rate;
}

console.log("=== Verifica listino vs estimateCostUsd ===\n");

// GPT-5.5: $5 input / $30 output (no cache)
{
  const input = 2000;
  const output = 500;
  const expected = perM(input, 5) + perM(output, 30);
  const actual = estimateCostUsd({
    model: "gpt-5.5",
    inputTokens: input,
    outputTokens: output,
  });
  assertClose(actual, expected, "gpt-5.5 2000in/500out");
}

// GPT-4.1 con cached: uncached $2, cached $0.5, out $8
{
  const input = 10000;
  const cached = 4000;
  const output = 1000;
  const expected =
    perM(input - cached, 2) + perM(cached, 0.5) + perM(output, 8);
  const actual = estimateCostUsd({
    model: "gpt-4.1",
    inputTokens: input,
    outputTokens: output,
    modality: { cachedTokens: cached },
  });
  assertClose(actual, expected, "gpt-4.1 con cached");
}

// NON deve più usare mini per default
{
  const asMini = perM(1000, 0.4) + perM(100, 1.6);
  const as55 = perM(1000, 5) + perM(100, 30);
  const actual = estimateCostUsd({
    model: "gpt-5.5",
    inputTokens: 1000,
    outputTokens: 100,
  });
  if (Math.abs(actual - asMini) < 1e-9) {
    console.error("FAIL bug gpt-4.1-mini ancora attivo");
    process.exitCode = 1;
  } else if (Math.abs(actual - as55) < 1e-6) {
    console.log("OK   non usa più gpt-4.1-mini per gpt-5.5");
  } else {
    console.error(`FAIL costo gpt-5.5 inatteso: ${actual}`);
    process.exitCode = 1;
  }
}

// Realtime sample da docs OpenAI (response.done usage)
{
  const usage = {
    total_tokens: 253,
    input_tokens: 132,
    output_tokens: 121,
    input_token_details: {
      text_tokens: 119,
      audio_tokens: 13,
      cached_tokens: 64,
      cached_tokens_details: {
        text_tokens: 64,
        audio_tokens: 0,
      },
    },
    output_token_details: {
      text_tokens: 30,
      audio_tokens: 91,
    },
  };
  const m = modalityFromRealtimeUsage(usage);
  // gpt-realtime-2.1: text in 4, text cached 0.4, audio in 32, text out 24, audio out 64
  const expected =
    perM(119 - 64, 4) +
    perM(13 - 0, 32) +
    perM(64, 0.4) +
    perM(0, 0.4) +
    perM(30, 24) +
    perM(91, 64);
  const actual = estimateCostUsd({
    model: "gpt-realtime",
    inputTokens: usage.input_tokens,
    outputTokens: usage.output_tokens,
    modality: m,
  });
  assertClose(actual, expected, "realtime audio/text/cached");
}

// Whisper 30s @ $0.006/min
{
  const expected = (30 / 60) * 0.006;
  const actual = estimateCostUsd({
    model: "whisper-1",
    inputTokens: 0,
    outputTokens: 0,
    whisperSeconds: 30,
  });
  assertClose(actual, expected, "whisper-1 30s");
}

async function liveChatCheck() {
  const apiKey = (process.env.OPENAI_API_KEY || "").trim();
  if (!apiKey) {
    console.log("\n(skip --live: OPENAI_API_KEY non impostata)");
    return;
  }
  console.log("\n=== Live Chat Completions vs tracker ===\n");
  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4.1-mini",
      messages: [
        { role: "user", content: "Rispondi solo con la parola OK." },
      ],
      max_completion_tokens: 16,
    }),
  });
  if (!response.ok) {
    console.error("OpenAI error:", response.status, await response.text());
    process.exitCode = 1;
    return;
  }
  const payload = await response.json();
  const usage = payload.usage || {};
  const input = usage.prompt_tokens || 0;
  const output = usage.completion_tokens || 0;
  const cached = usage.prompt_tokens_details?.cached_tokens || 0;
  const expected =
    perM(Math.max(0, input - cached), 0.4) +
    perM(cached, 0.1) +
    perM(output, 1.6);
  const actual = estimateCostUsd({
    model: "gpt-4.1-mini",
    inputTokens: input,
    outputTokens: output,
    modality: cached > 0 ? { cachedTokens: cached } : undefined,
  });
  console.log("OpenAI usage:", JSON.stringify(usage));
  assertClose(actual, expected, "live gpt-4.1-mini vs listino");
}

(async () => {
  if (process.argv.includes("--live")) {
    await liveChatCheck();
  }
  if (process.exitCode) {
    console.error("\nVerifica FALLITA");
    process.exit(process.exitCode);
  }
  console.log("\nVerifica OK");
})();
