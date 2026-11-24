import { readFileSync } from 'node:fs';
import { isAbsolute } from 'node:path';
import { cert } from 'firebase-admin/app';

export function openRouterKey(env = process.env) {
  const key = env.OPENROUTER_API_KEY?.trim();
  return key && key !== 'paste_your_openrouter_key_here' ? key : undefined;
}

export function runtimeConfig(env = process.env) {
  const render = env.RENDER === 'true';
  const production = render || env.NODE_ENV === 'production';
  const port = Number(env.PORT || 3001);
  const projectId = env.FIREBASE_PROJECT_ID?.trim();
  // Local development and emulator tests can use Firebase application defaults.
  let credential;

  const minimumPort = production ? 1 : 0;
  if (!Number.isInteger(port) || port < minimumPort || port > 65535) {
    throw new Error(`PORT must be an integer between ${minimumPort} and 65535.`);
  }
  if (render) {
    if (!openRouterKey(env)) throw new Error('OPENROUTER_API_KEY is required.');
    if (!projectId) throw new Error('FIREBASE_PROJECT_ID is required.');
    if (env.FIREBASE_AUTH_EMULATOR_HOST || env.FIRESTORE_EMULATOR_HOST) {
      throw new Error('Firebase emulator settings are forbidden on Render.');
    }

    try {
      const path = env.GOOGLE_APPLICATION_CREDENTIALS;
      if (!path || !isAbsolute(path)) throw new Error();
      const account = JSON.parse(readFileSync(path, 'utf8'));
      if (account.type !== 'service_account' || account.project_id !== projectId) {
        throw new Error();
      }
      credential = cert(account);
    } catch {
      // SDK and filesystem errors can include secret paths or credential details.
      throw new Error('Mount a valid service-account secret file for FIREBASE_PROJECT_ID and set GOOGLE_APPLICATION_CREDENTIALS to its absolute path.');
    }
  }

  return {
    render,
    port,
    projectId,
    credential,
    accountDeletionEnabled:
      !production && env.SMARTSAVE_ENABLE_ACCOUNT_DELETION === 'true',
  };
}
