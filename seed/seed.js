'use strict';

/**
 * Telli Local Seeder
 *
 * Seeds both telli_api_db and telli_dialog_db with the minimum data
 * required for a working local Telli instance.
 *
 * Uses a fixed, well-known local API key so no secret-sharing between
 * containers is needed. This key is NOT safe for production use.
 *
 * Fixed local API key:
 *   keyId  : local
 *   secret : telli-local-secret-not-for-production
 *   fullKey: sk-local.telli-local-secret-not-for-production
 */

const { Client } = require('pg');
const bcrypt = require('bcryptjs');

// ---------------------------------------------------------------------------
// Fixed identifiers
// ---------------------------------------------------------------------------
const ORG_ID      = 'cfeb82c6-396a-4c2d-954b-53e77acbbe7e';
const PROJECT_ID  = 'DE-TEST';
const STATE_ID    = 'DE-TEST';

// Fixed local API key – deterministic, no runtime secret generation needed
const API_KEY_ID      = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'; // stable UUID for the api_key row
const API_KEY_ID_TEXT = 'local';
const API_KEY_SECRET  = 'telli-local-secret-not-for-production';
const FULL_API_KEY = `sk-${API_KEY_ID_TEXT}.${API_KEY_SECRET}`;

// LLM model definitions – same IDs in both databases
const LLM_MODELS = [
  {
    id:          'b870b74d-7458-4dcf-99f6-ace83ef514f4',
    provider:    'ionos',       // owner in dialog DB, provider in api DB
    name:        'BAAI/bge-m3',
    displayName: 'BGE-M3 Embedding',
    description: 'Embedding model for semantic search',
    type:        'embedding',
    settings:    { type: 'embedding' },
    priceMetadata: { inputCostPer1kTokens: 0, outputCostPer1kTokens: 0 },
  },
  {
    id:          '7dcb063f-5241-4846-b11f-a621ea1dd4a9',
    provider:    'ionos',
    name:        'black-forest-labs/FLUX.1-schnell',
    displayName: 'FLUX.1 Schnell (Image)',
    description: 'Fast image generation model',
    type:        'image',
    settings:    { type: 'image' },
    priceMetadata: { costPerImage: 0 },
  },
  {
    id:          '9578ed80-b0c2-4968-b253-d897576e5512',
    provider:    'ionos',
    name:        'meta-llama/Llama-3.3-70B-Instruct',
    displayName: 'Llama 3.3 70B Instruct',
    description: 'Open-source large language model by Meta',
    type:        'text',
    settings:    { type: 'chat' },
    priceMetadata: { inputCostPer1kTokens: 0, outputCostPer1kTokens: 0 },
  },
  {
    id:          '4f8a2c1e-93d7-4b6a-a5e0-d2f1c8b7e3a9',
    provider:    'openai',
    name:        'gemini-2.5-flash',
    displayName: 'Gemini 2.5 Flash',
    description: 'Fast and efficient Gemini model by Google',
    type:        'text',
    settings:    { type: 'chat' },
    priceMetadata: { inputCostPer1kTokens: 0, outputCostPer1kTokens: 0 },
  },
  {
    id:          'e7b3d9f2-1a4c-4e8b-b6d5-f0c2a9e8d1b7',
    provider:    'openai',
    name:        'gemini-2.5-pro',
    displayName: 'Gemini 2.5 Pro',
    description: 'Powerful Gemini Pro model by Google',
    type:        'text',
    settings:    { type: 'chat' },
    priceMetadata: { inputCostPer1kTokens: 0, outputCostPer1kTokens: 0 },
  },
];

const FEATURE_TOGGLES = {
  isStudentAccessEnabled:          true,
  isCharacterEnabled:              true,
  isSharedChatEnabled:             true,
  isCustomGptEnabled:              true,
  isShareTemplateWithSchoolEnabled: true,
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function log(msg) {
  const ts = new Date().toISOString();
  console.log(`[${ts}] ${msg}`);
}

function logSection(title) {
  console.log('');
  console.log(`${'='.repeat(60)}`);
  console.log(`  ${title}`);
  console.log(`${'='.repeat(60)}`);
}

async function connectWithRetry(url, label, maxRetries = 20, delayMs = 3000) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    const client = new Client({ connectionString: url });
    try {
      await client.connect();
      log(`Connected to ${label} (attempt ${attempt})`);
      return client;
    } catch (err) {
      log(`Cannot connect to ${label} (attempt ${attempt}/${maxRetries}): ${err.message}`);
      await client.end().catch(() => {});
      if (attempt === maxRetries) {
        throw new Error(`Failed to connect to ${label} after ${maxRetries} attempts`);
      }
      await new Promise((r) => setTimeout(r, delayMs));
    }
  }
}

// ---------------------------------------------------------------------------
// API DB seeding
// ---------------------------------------------------------------------------

async function seedApiDb(apiDb, llmApiKey, llmBaseUrl) {
  logSection('Seeding API Database (telli_api_db)');

  // 1. Organization
  log('Inserting organization...');
  await apiDb.query(
    `INSERT INTO organization (id, name)
     VALUES ($1, $2)
     ON CONFLICT (id) DO NOTHING`,
    [ORG_ID, 'Telli Local']
  );

  // 2. Project
  log('Inserting project...');
  await apiDb.query(
    `INSERT INTO project (id, name, organization_id)
     VALUES ($1, $2, $3)
     ON CONFLICT (id) DO NOTHING`,
    [PROJECT_ID, 'Telli Local Project', ORG_ID]
  );

  // 3. LLM Models in API DB
  log('Inserting LLM models into API DB...');
  for (const model of LLM_MODELS) {
    await apiDb.query(
      `INSERT INTO llm_model (id, provider, name, display_name, description, settings, price_metada, organization_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (id) DO UPDATE
         SET provider     = EXCLUDED.provider,
             name         = EXCLUDED.name,
             display_name = EXCLUDED.display_name,
             description  = EXCLUDED.description,
             settings     = EXCLUDED.settings`,
      [
        model.id,
        model.provider,
        model.name,
        model.displayName,
        model.description,
        JSON.stringify({
          provider: model.provider,
          apiKey:   llmApiKey,
          baseUrl:  llmBaseUrl,
        }),
        JSON.stringify(model.priceMetadata),
        ORG_ID,
      ]
    );
    log(`  - ${model.displayName} (${model.id})`);
  }

  // 4. API Key (the internal telli-api key used by dialog/admin apps)
  log('Inserting internal API key...');

  // Compute bcrypt hash of the fixed local secret at runtime
  log('  Computing bcrypt hash of local API secret (this takes a moment)...');
  const secretHash = await bcrypt.hash(API_KEY_SECRET, 10);

  await apiDb.query(
    `INSERT INTO api_key (id, name, key_id, secret_hash, project_id, state, limit_in_cent)
     VALUES ($1, $2, $3, $4, $5, 'active', 0)
     ON CONFLICT (id) DO UPDATE
       SET name        = EXCLUDED.name,
           key_id      = EXCLUDED.key_id,
           secret_hash = EXCLUDED.secret_hash`,
    [API_KEY_ID, 'Telli Local API Key', API_KEY_ID_TEXT, secretHash, PROJECT_ID]
  );

  // 5. LLM Model <-> API Key mappings
  log('Inserting LLM model <-> API key mappings...');
  for (const model of LLM_MODELS) {
    // llm_model_api_key_mapping has no unique constraint; check before insert
    const existing = await apiDb.query(
      `SELECT id FROM llm_model_api_key_mapping
       WHERE llm_model_id = $1 AND api_key_id = $2`,
      [model.id, API_KEY_ID]
    );
    if (existing.rowCount === 0) {
      await apiDb.query(
        `INSERT INTO llm_model_api_key_mapping (llm_model_id, api_key_id)
         VALUES ($1, $2)`,
        [model.id, API_KEY_ID]
      );
    }
  }

  log('API DB seeding complete.');
}

// ---------------------------------------------------------------------------
// Dialog DB seeding
// ---------------------------------------------------------------------------

async function seedDialogDb(dialogDb) {
  logSection('Seeding Dialog Database (telli_dialog_db)');

  // 1. LLM Models in Dialog DB
  log('Inserting LLM models into Dialog DB...');
  for (const model of LLM_MODELS) {
    await dialogDb.query(
      `INSERT INTO llm_model (id, owner, name, display_name, description, price_metada)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (id) DO UPDATE
         SET owner        = EXCLUDED.owner,
             name         = EXCLUDED.name,
             display_name = EXCLUDED.display_name,
             description  = EXCLUDED.description`,
      [
        model.id,
        model.provider,
        model.name,
        model.displayName,
        model.description,
        JSON.stringify(model.priceMetadata),
      ]
    );
    log(`  - ${model.displayName} (${model.id})`);
  }

  // 2. Federal State
  log('Inserting federal state...');
  await dialogDb.query(
    `INSERT INTO federal_state (
       id,
       teacher_price_limit,
       student_price_limit,
       api_key_id,
       feature_toggles
     ) VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (id) DO UPDATE
       SET teacher_price_limit = EXCLUDED.teacher_price_limit,
           student_price_limit = EXCLUDED.student_price_limit,
           api_key_id          = EXCLUDED.api_key_id,
           feature_toggles     = EXCLUDED.feature_toggles`,
    [
      STATE_ID,
      100000, // teacher limit in cent (1000 EUR – generous for local dev)
      100000, // student limit in cent
      API_KEY_ID,
      JSON.stringify(FEATURE_TOGGLES),
    ]
  );

  // 3. Federal State <-> LLM Model mappings
  log('Inserting federal state <-> LLM model mappings...');
  for (const model of LLM_MODELS) {
    await dialogDb.query(
      `INSERT INTO federal_state_llm_model_mapping (federal_state_id, llm_model_id)
       VALUES ($1, $2)
       ON CONFLICT DO NOTHING`,
      [STATE_ID, model.id]
    );
  }

  log('Dialog DB seeding complete.');
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  logSection('Telli Local Database Seeder');

  const apiDbUrl    = process.env.API_DATABASE_URL;
  const dialogDbUrl = process.env.DATABASE_URL;
  const llmApiKey   = process.env.LLM_API_KEY;
  const llmBaseUrl  = process.env.LLM_BASE_URL || 'https://openai.ionos.de/openai';

  if (!apiDbUrl) {
    console.error('ERROR: API_DATABASE_URL environment variable is required');
    process.exit(1);
  }
  if (!dialogDbUrl) {
    console.error('ERROR: DATABASE_URL environment variable is required');
    process.exit(1);
  }
  if (!llmApiKey) {
    console.error('ERROR: LLM_API_KEY environment variable is required');
    process.exit(1);
  }

  log(`LLM Base URL : ${llmBaseUrl}`);
  log(`LLM API Key  : ${llmApiKey.substring(0, 8)}... (redacted)`);
  log(`Fixed API key: ${FULL_API_KEY}`);
  console.log('');
  log('NOTE: The fixed local API key is for LOCAL DEVELOPMENT ONLY.');
  log('      Do NOT expose this key on a public network.');

  let apiDb    = null;
  let dialogDb = null;

  try {
    // Connect to both databases (with retry, since postgres may still be starting)
    [apiDb, dialogDb] = await Promise.all([
      connectWithRetry(apiDbUrl,    'API DB (telli_api_db)'),
      connectWithRetry(dialogDbUrl, 'Dialog DB (telli_dialog_db)'),
    ]);

    // Seed both databases
    await seedApiDb(apiDb, llmApiKey, llmBaseUrl);
    await seedDialogDb(dialogDb);

    logSection('Seeding Complete');
    console.log('');
    log(`Internal API key (TELLI_API_KEY): ${FULL_API_KEY}`);
    log('');
    log('Services will be available at:');
    log('  Dialog  -> http://localhost:3000');
    log('  Admin   -> http://localhost:3001');
    log('  API     -> http://localhost:3002');
    log('  Keycloak-> http://localhost:8080');
    log('');
    log('Default Keycloak admin credentials: admin / admin');
    log('Create users at: http://localhost:8080/admin -> realm "telli-local"');

  } catch (err) {
    console.error('');
    console.error('FATAL ERROR during seeding:');
    console.error(err.message);
    if (err.detail) console.error('Detail:', err.detail);
    process.exit(1);
  } finally {
    if (apiDb)    await apiDb.end().catch(() => {});
    if (dialogDb) await dialogDb.end().catch(() => {});
  }
}

main();
