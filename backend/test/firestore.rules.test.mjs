import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteDoc, deleteField, doc, getDoc, runTransaction, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';

let environment;
const date = '2026-01-01T00:00:00.000Z';
const sync = {
  id: '', localId: '1', createdAt: date, updatedAt: date, isSynced: true,
  isDeleted: false, version: 1, syncStatus: 'synced',
};
const transaction = {
  ...sync, amount: 100, isIncome: false, category: 'Food', merchant: 'Store', occurredAt: date,
  note: '', source: 'Manual entry',
};

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-smartsave-rules',
    firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(async () => environment?.cleanup());

function record(actor, path) {
  const context = actor ? environment.authenticatedContext(actor) : environment.unauthenticatedContext();
  return doc(context.firestore(), path);
}

test('owner can create, read and soft-delete a valid transaction', async () => {
  const ref = record('alice', 'users/alice/transactions/valid');
  await assertSucceeds(setDoc(ref, transaction));
  await assertSucceeds(getDoc(ref));
  await assertSucceeds(updateDoc(ref, { isDeleted: true, updatedAt: serverTimestamp(), version: 2 }));
});

test('anonymous and cross-account callers cannot read or write private records', async () => {
  const path = 'users/alice/transactions/private';
  await assertSucceeds(setDoc(record('alice', path), transaction));
  for (const actor of [null, 'bob']) {
    await assertFails(getDoc(record(actor, path)));
    await assertFails(setDoc(record(actor, 'users/alice/transactions/new'), transaction));
    await assertFails(updateDoc(record(actor, path), { amount: 500 }));
    await assertFails(deleteDoc(record(actor, 'users/alice/goals/savings')));
  }
});

test('invalid types, ownership changes and unsupported paths are denied', async () => {
  const ref = record('alice', 'users/alice/transactions/ownership');
  await assertFails(setDoc(ref, { ...transaction, amount: '100' }));
  await assertFails(setDoc(ref, { ...transaction, userId: 'bob' }));
  await assertSucceeds(setDoc(ref, { ...transaction, userId: 'alice' }));
  await assertFails(updateDoc(ref, { userId: 'bob' }));
  await assertFails(updateDoc(ref, { userId: deleteField() }));
  await assertFails(setDoc(record('alice', 'users/alice/unknown/record'), transaction));
});

test('assessment history is append only and bound to its parent', async () => {
  const ref = record('alice', 'users/alice/investmentTheses/thesis1/assessments/assessment1');
  const assessment = { ...sync, thesisId: 'thesis1', assessedAt: date, conditions: [] };
  await assertFails(setDoc(ref, { ...assessment, thesisId: 'other' }));
  await assertSucceeds(setDoc(ref, assessment));
  await assertFails(updateDoc(ref, { assessedAt: 'changed' }));
  await assertFails(deleteDoc(ref));
});

test('sync metadata must carry the authenticated owner UID', async () => {
  const ref = record('alice', 'users/alice/syncMetadata/metadata');
  const metadata = { ...sync, userId: 'alice', lastFullSync: date, pendingUploadCount: 0,
    schemaVersion: 1, entityVersions: {} };
  await assertFails(setDoc(ref, { ...metadata, userId: 'bob' }));
  await assertSucceeds(setDoc(ref, metadata));
});

test('a server deletion lock blocks the owner and cannot be cleared by the client', async () => {
  const ref = record('alice', 'users/alice/transactions/locked');
  await assertSucceeds(setDoc(ref, transaction));
  await environment.withSecurityRulesDisabled(async (admin) => {
    await setDoc(doc(admin.firestore(), 'accountDeletionLocks/alice'), { locked: true });
  });
  await assertFails(getDoc(ref));
  await assertFails(setDoc(ref, transaction));
  await assertFails(deleteDoc(record('alice', 'accountDeletionLocks/alice')));
  await assertSucceeds(setDoc(record('bob', 'users/bob/transactions/unlocked'), transaction));
});

test('investment tombstones cannot be reverted, and assessment history remains readable', async () => {
  const thesis = 'users/investor/investmentTheses/project';
  const holding = 'users/investor/portfolioHoldings/holding';
  const assessment = `${thesis}/assessments/history`;
  await assertSucceeds(setDoc(record('investor', thesis), {
    ...sync, securityName: 'Fixture', rationale: '', horizon: '',
  }));
  await assertSucceeds(setDoc(record('investor', holding), {
    ...sync, securityName: 'Fixture', marketValueKzt: 12000,
  }));
  await assertSucceeds(setDoc(record('investor', assessment), {
    ...sync, thesisId: 'project', assessedAt: date, conditions: [],
  }));
  for (const path of [thesis, holding]) {
    await assertFails(updateDoc(record('another-user', path), { isDeleted: true }));
    const owner = record('investor', path);
    await assertSucceeds(updateDoc(owner, { isDeleted: true, version: 2 }));
    await assertFails(updateDoc(owner, { isDeleted: false, version: 3 }));
    await assertFails(deleteDoc(owner));
  }
  assert.equal((await assertSucceeds(getDoc(record('investor', assessment)))).exists(), true);
});

test('two competing transactions cannot both commit the same revision', async () => {
  const path = 'users/revision-owner/transactions/same-record';
  await assertSucceeds(setDoc(record('revision-owner', path), transaction));
  const updateAtRevision = async (amount) => {
    const ref = record('revision-owner', path);
    return runTransaction(ref.firestore, async (txn) => {
      const snapshot = await txn.get(ref);
      if (snapshot.data().version !== 1) return false;
      txn.update(ref, { amount, version: 2 });
      return true;
    });
  };
  const results = await Promise.allSettled([updateAtRevision(120), updateAtRevision(245)]);
  assert.equal(results.filter((result) => result.status === 'fulfilled' && result.value).length, 1);
  for (const result of results) {
    if (result.status === 'rejected') {
      assert.ok(['permission-denied', 'aborted'].includes(result.reason.code));
    }
  }
  const ref = record('revision-owner', path);
  const updated = (await getDoc(ref)).data();
  assert.equal(updated.version, 2);
  assert.ok([120, 245].includes(updated.amount));
  await assertFails(updateDoc(ref, { amount: 500, version: 2 }));
  await assertSucceeds(updateDoc(ref, { isDeleted: true, version: 3 }));
  await assertFails(updateDoc(ref, { isDeleted: false, version: 4 }));
});

test('goal deletion leaves a tombstone and the linked contribution readable', async () => {
  const path = 'users/goal-owner/goals/goal';
  const goal = record('goal-owner', path);
  const contribution = record('goal-owner', `${path}/contributions/contribution`);
  await assertSucceeds(setDoc(goal, {
    ...sync, name: 'Fixture', target: 500, saved: 100, deadline: date,
  }));
  await assertSucceeds(setDoc(contribution, {
    ...sync, goalId: 'goal', amount: 100, contributedAt: date,
  }));
  await assertFails(deleteDoc(goal));
  await assertSucceeds(updateDoc(goal, { isDeleted: true, version: 2 }));
  await assertFails(updateDoc(goal, { isDeleted: false, version: 3 }));
  assert.equal((await getDoc(contribution)).exists(), true);
});

test('web operation markers are immutable and private to the account', async () => {
  const path = 'users/web-owner/webOperations/web-fixture';
  const marker = { target: 'transactions/web-fixture', fingerprint: 'a'.repeat(64) };
  await assertSucceeds(setDoc(record('web-owner', path), marker));
  await assertSucceeds(getDoc(record('web-owner', path)));
  await assertFails(setDoc(record('web-owner', path), { ...marker, target: 'goals/changed' }));
  await assertFails(deleteDoc(record('web-owner', path)));
  await assertFails(getDoc(record('bob', path)));
  await assertFails(getDoc(record(null, path)));
  await assertFails(setDoc(record('web-owner', 'users/web-owner/webOperations/invalid'), {
    ...marker, fingerprint: 'unhashed payload',
  }));
});

test('web conversations and locale enforce account isolation and revisions', async () => {
  const transcript = { ...sync, title: 'Disposable thread', transcript: '[]' };
  const thread = 'users/web-owner/webConversations/web-fixture';
  const locale = 'users/web-owner/webPreferences/locale';
  await assertSucceeds(setDoc(record('web-owner', thread), transcript));
  await assertFails(getDoc(record('bob', thread)));
  await assertFails(setDoc(record('bob', thread), { ...transcript, version: 2 }));
  await assertFails(updateDoc(record('web-owner', thread), { title: 'stale' }));
  await assertSucceeds(updateDoc(record('web-owner', thread), { title: 'current', version: 2 }));
  await assertFails(updateDoc(record('web-owner', thread), { transcript: 'x'.repeat(100001), version: 3 }));
  await assertFails(setDoc(record('web-owner', locale), { ...sync, locale: 'de' }));
  await assertSucceeds(setDoc(record('web-owner', locale), { ...sync, locale: 'kk' }));
  await assertFails(getDoc(record('bob', locale)));
});
