import assert from 'node:assert/strict';
import { Server } from 'node:http';
import { test } from 'node:test';
import { getApp } from 'firebase-admin/app';
import { getFirestore as getAdminFirestore } from 'firebase-admin/firestore';
import { deleteApp, initializeApp } from 'firebase/app';
import {
  applyActionCode, confirmPasswordReset, connectAuthEmulator, createUserWithEmailAndPassword,
  deleteUser, getAuth, reload, sendEmailVerification, sendPasswordResetEmail,
  signInWithEmailAndPassword, signOut,
} from 'firebase/auth';
import {
  connectFirestoreEmulator, disableNetwork, doc, enableNetwork, getDocFromServer,
  getFirestore, setDoc, updateDoc,
} from 'firebase/firestore';

const projectId = 'demo-smartsave-stage6';
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
for (const host of [authHost, firestoreHost]) {
  assert.match(host ?? '', /^127\.0\.0\.1:\d+$/, 'A loopback emulator is required');
}

process.env.FIREBASE_PROJECT_ID = projectId;
process.env.SMARTSAVE_ENABLE_ACCOUNT_DELETION = 'true';
process.env.OPENROUTER_API_KEY = 'integration-fixture';
process.env.PORT = '0';

function createClient(name) {
  const app = initializeApp({ projectId, apiKey: 'demo-emulator-only' }, name);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${authHost}`, { disableWarnings: true });
  const firestore = getFirestore(app);
  connectFirestoreEmulator(firestore, '127.0.0.1', Number(firestoreHost.split(':')[1]));
  return { app, auth, firestore };
}

function changeTokenClaims(token, changes) {
  const [header, claims] = token.split('.');
  const changed = { ...JSON.parse(Buffer.from(claims, 'base64url')), ...changes };
  return `${header}.${Buffer.from(JSON.stringify(changed)).toString('base64url')}.`;
}

test('emulator Auth, Firebase Admin verification, offline Firestore and account cleanup', async (t) => {
  const first = createClient('first');
  const restart = createClient('restart');
  const other = createClient('other');
  t.after(async () => {
    await Promise.all([first, restart, other].map(({ app }) => deleteApp(app)));
  });

  const realListen = Server.prototype.listen;
  let server;
  Server.prototype.listen = function (...args) {
    server = this;
    return realListen.apply(this, args);
  };
  const realFetch = globalThis.fetch;
  globalThis.fetch = (url, ...args) => {
    if (String(url).startsWith('https://openrouter.ai/')) {
      return Promise.resolve(new Response(JSON.stringify({
        choices: [{ message: { content: 'fixture reply' } }],
      }), { headers: { 'content-type': 'application/json' } }));
    }
    return realFetch(url, ...args);
  };
  t.after(() => {
    globalThis.fetch = realFetch;
    server?.closeAllConnections?.();
    server?.close();
  });
  try {
    await import('../server.js');
  } finally {
    Server.prototype.listen = realListen;
  }
  const endpoint = `http://127.0.0.1:${server.address().port}`;
  const email = `owner-${Date.now()}@example.test`;
  const password = ['synthetic', 'fixture', 'only'].join('-');
  const { user: original } = await createUserWithEmailAndPassword(first.auth, email, password);
  const uid = original.uid;
  const actionCode = async (requestType) => {
    const response = await realFetch(`http://${authHost}/emulator/v1/projects/${projectId}/oobCodes`);
    assert.equal(response.status, 200);
    const { oobCodes } = await response.json();
    const match = oobCodes.find((item) => item.email === email && item.requestType === requestType);
    assert.ok(match);
    return match.oobCode;
  };
  assert.equal(original.emailVerified, false);
  await sendEmailVerification(original);
  await applyActionCode(first.auth, await actionCode('VERIFY_EMAIL'));
  await reload(original);
  assert.equal(original.emailVerified, true);
  const { user: outsider } = await createUserWithEmailAndPassword(
    other.auth, `other-${Date.now()}@example.test`, password,
  );
  const date = '2026-01-01T00:00:00.000Z';
  const sync = {
    id: 'stable-id', localId: '1', createdAt: date, updatedAt: date, isSynced: true,
    isDeleted: false, version: 1, syncStatus: 'synced',
  };
  const transaction = {
    ...sync, amount: 100, isIncome: false, category: 'Food', merchant: 'Fixture',
    occurredAt: date, note: '', source: 'Manual entry',
  };
  const transactionPath = `users/${uid}/transactions/stable-id`;
  const childPath = `users/${uid}/investmentTheses/orphan/assessments/history`;
  const otherPath = `users/${outsider.uid}/transactions/stable-id`;
  await setDoc(doc(first.firestore, transactionPath), transaction);
  await setDoc(doc(first.firestore, childPath), {
    ...sync, thesisId: 'orphan', assessedAt: date, conditions: [],
  });
  await setDoc(doc(other.firestore, otherPath), transaction);
  await assert.rejects(getDocFromServer(doc(other.firestore, transactionPath)), { code: 'permission-denied' });

  await signOut(first.auth);
  await sendPasswordResetEmail(restart.auth, email);
  const newPassword = [password, 'changed'].join('-');
  await confirmPasswordReset(restart.auth, await actionCode('PASSWORD_RESET'), newPassword);
  await assert.rejects(signInWithEmailAndPassword(restart.auth, email, password));
  const { user } = await signInWithEmailAndPassword(restart.auth, email, newPassword);
  assert.equal(user.uid, uid);
  const restored = doc(restart.firestore, transactionPath);
  assert.equal((await getDocFromServer(restored)).data().amount, 100);
  await disableNetwork(restart.firestore);
  const offlineWrite = updateDoc(restored, { amount: 275, version: 2 });
  await enableNetwork(restart.firestore);
  await offlineWrite;
  assert.equal((await getDocFromServer(restored)).data().amount, 275);

  const token = await user.getIdToken();
  const post = (path, bearer) => realFetch(endpoint + path, {
    method: 'POST',
    headers: { authorization: `Bearer ${bearer}`, 'content-type': 'application/json' },
    body: JSON.stringify({ messages: [{ role: 'user', content: 'synthetic prompt' }] }),
  });
  const completions = '/api/chat/completions';
  const reply = await post(completions, token);
  assert.equal(reply.status, 200);
  assert.equal((await reply.json()).choices[0].message.content, 'fixture reply');
  assert.equal((await post(completions, changeTokenClaims(token, { aud: 'demo-other' }))).status, 401);
  assert.equal((await post(completions, changeTokenClaims(token, { exp: 1 }))).status, 401);

  const deletion = '/api/account/delete-data';
  assert.equal((await post(deletion, token)).status, 204);
  assert.equal((await post(deletion, token)).status, 204);
  const admin = getAdminFirestore(getApp());
  assert.equal((await admin.doc(transactionPath).get()).exists, false);
  assert.equal((await admin.doc(childPath).get()).exists, false);
  assert.equal((await admin.doc(otherPath).get()).exists, true);
  await assert.rejects(setDoc(restored, transaction), { code: 'permission-denied' });
  await deleteUser(user);
  await assert.rejects(signInWithEmailAndPassword(restart.auth, email, newPassword));
});
