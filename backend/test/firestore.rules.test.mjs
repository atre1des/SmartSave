import { after, before, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteDoc, deleteField, doc, getDoc, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';

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
