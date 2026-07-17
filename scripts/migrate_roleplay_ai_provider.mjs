/**
 * Migra aiProvider → "realtime" su tutte le simulazioni Firestore `roleplay/*`.
 *
 * Uso:
 *   node scripts/migrate_roleplay_ai_provider.mjs
 *   node scripts/migrate_roleplay_ai_provider.mjs --dry-run
 *
 * Prerequisiti:
 *   cd functions && npm ci
 *   firebase login
 *   gcloud auth application-default login
 *     oppure: $env:GOOGLE_APPLICATION_CREDENTIALS="path\serviceAccount.json"
 */
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const admin = require(
  join(dirname(fileURLToPath(import.meta.url)), '../functions/node_modules/firebase-admin'),
);

const PROJECT_ID = 'creditform-d505d';
const COLLECTION = 'roleplay';
const TARGET_PROVIDER = 'realtime';
const BATCH_SIZE = 400;

const dryRun = process.argv.includes('--dry-run');

function normalizeProvider(raw) {
  if (raw == null || String(raw).trim() === '') return '';
  return String(raw).toLowerCase().trim();
}

function shouldMigrate(current) {
  return normalizeProvider(current) !== TARGET_PROVIDER;
}

admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

const snapshot = await db.collection(COLLECTION).get();
console.log(`\n=== Migrazione roleplay aiProvider → ${TARGET_PROVIDER} ===`);
console.log(`Progetto: ${PROJECT_ID}`);
console.log(`Documenti trovati: ${snapshot.size}`);
console.log(dryRun ? 'Modalità: DRY-RUN (nessuna scrittura)\n' : 'Modalità: SCRITTURA\n');

const toUpdate = [];
const alreadyOk = [];

for (const doc of snapshot.docs) {
  const data = doc.data();
  const current = data.aiProvider;
  const title = (data.title ?? doc.id).toString();

  if (shouldMigrate(current)) {
    toUpdate.push({
      id: doc.id,
      title,
      from: current == null || String(current).trim() === '' ? '(assente)' : String(current),
    });
  } else {
    alreadyOk.push({ id: doc.id, title });
  }
}

console.log(`Già ${TARGET_PROVIDER}: ${alreadyOk.length}`);
console.log(`Da aggiornare: ${toUpdate.length}\n`);

if (toUpdate.length === 0) {
  console.log('Nessuna migrazione necessaria.');
  process.exit(0);
}

for (const row of toUpdate) {
  console.log(`  • ${row.id}  "${row.title}"  ${row.from} → ${TARGET_PROVIDER}`);
}

if (dryRun) {
  console.log('\nDry-run completato. Riesegui senza --dry-run per applicare.');
  process.exit(0);
}

let updated = 0;
for (let i = 0; i < toUpdate.length; i += BATCH_SIZE) {
  const chunk = toUpdate.slice(i, i + BATCH_SIZE);
  const batch = db.batch();

  for (const row of chunk) {
    const ref = db.collection(COLLECTION).doc(row.id);
    batch.set(
      ref,
      {
        aiProvider: TARGET_PROVIDER,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  await batch.commit();
  updated += chunk.length;
  console.log(`\nBatch committato: ${updated}/${toUpdate.length}`);
}

console.log(`\nOK: ${updated} simulazioni aggiornate a aiProvider="${TARGET_PROVIDER}".`);
