import { spawnSync } from 'node:child_process';
import { generateKeyPairSync } from 'node:crypto';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
import test from 'node:test';

import { openRouterKey, runtimeConfig } from '../runtime_config.js';

const cloud = {
  RENDER: 'true',
  PORT: '10000',
  OPENROUTER_API_KEY: 'fixture-value',
  FIREBASE_PROJECT_ID: 'demo-smartsave-cloud',
};

test('local/emulator defaults remain usable and production cannot enable deletion', () => {
  assert.deepEqual(runtimeConfig({}), {
    render: false,
    port: 3001,
    projectId: undefined,
    credential: undefined,
    accountDeletionEnabled: false,
  });
  assert.equal(runtimeConfig({ PORT: '0' }).port, 0);
  assert.equal(runtimeConfig({ SMARTSAVE_ENABLE_ACCOUNT_DELETION: 'true' }).accountDeletionEnabled, true);
  assert.equal(runtimeConfig({
    NODE_ENV: 'production', SMARTSAVE_ENABLE_ACCOUNT_DELETION: 'true',
  }).accountDeletionEnabled, false);
});

test('Render rejects missing configuration, emulator attributes and invalid ports', () => {
  assert.throws(() => runtimeConfig({ ...cloud, PORT: 'not-a-port' }), /PORT/);
  assert.throws(() => runtimeConfig({ ...cloud, PORT: '0' }), /PORT/);
  assert.throws(() => runtimeConfig({ ...cloud, OPENROUTER_API_KEY: '' }), /OPENROUTER_API_KEY/);
  assert.throws(() => runtimeConfig({ ...cloud, FIREBASE_PROJECT_ID: '' }), /FIREBASE_PROJECT_ID/);
  assert.throws(() => runtimeConfig({ ...cloud, FIREBASE_AUTH_EMULATOR_HOST: 'localhost:9099' }), /emulator/);
  assert.throws(() => runtimeConfig(cloud), /GOOGLE_APPLICATION_CREDENTIALS/);
  assert.equal(openRouterKey({ OPENROUTER_API_KEY: ' paste_your_openrouter_key_here ' }), undefined);
});

test('Render loads a matching mounted credential and forces deletion off', (t) => {
  const directory = mkdtempSync(join(tmpdir(), 'smartsave-config-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const credentialPath = join(directory, 'firebase.json');
  const { privateKey } = generateKeyPairSync('rsa', {
    modulusLength: 2048,
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    publicKeyEncoding: { type: 'spki', format: 'pem' },
  });
  writeFileSync(credentialPath, JSON.stringify({
    type: 'service_account',
    project_id: cloud.FIREBASE_PROJECT_ID,
    client_email: 'emulator-fixture@example.invalid',
    private_key: privateKey,
  }), { mode: 0o600 });

  const env = {
    ...cloud,
    GOOGLE_APPLICATION_CREDENTIALS: credentialPath,
    SMARTSAVE_ENABLE_ACCOUNT_DELETION: 'true',
  };
  const config = runtimeConfig(env);
  assert.equal(config.render, true);
  assert.equal(config.port, 10000);
  assert.equal(config.projectId, cloud.FIREBASE_PROJECT_ID);
  assert.equal(typeof config.credential.getAccessToken, 'function');
  assert.equal(config.accountDeletionEnabled, false);
  assert.throws(() => runtimeConfig({ ...env, FIREBASE_PROJECT_ID: 'wrong-project' }), /GOOGLE_APPLICATION_CREDENTIALS/);
  writeFileSync(credentialPath, 'malformed fixture');
  assert.throws(() => runtimeConfig(env), /GOOGLE_APPLICATION_CREDENTIALS/);
});

test('server exits before listening when cloud configuration is incomplete', () => {
  const result = spawnSync(process.execPath, [fileURLToPath(new URL('../server.js', import.meta.url))], {
    env: { RENDER: 'true' },
    timeout: 5000,
    encoding: 'utf8',
  });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /OPENROUTER_API_KEY is required/);
  assert.equal(result.stdout, '');
});
