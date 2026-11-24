import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const rules = readFileSync(resolve(root, 'firestore.rules'), 'utf8');
const code = 'ABCD2345';
const ownerDevice = 'a'.repeat(64);
const friendDevice = 'b'.repeat(64);
const otherDevice = 'c'.repeat(64);

const testEnv = await initializeTestEnvironment({
  projectId: 'demo-idle-party',
  firestore: { rules, host: '127.0.0.1', port: 8080 },
});

let failed = 0;

async function check(name, fn) {
  try {
    await fn();
    console.log(`ok  ${name}`);
  } catch (error) {
    failed++;
    console.error(`FAIL ${name}`);
    console.error(error);
  }
}

await testEnv.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'friendCodes', code), {
    ownerDevice,
    ownerUid: 'owner-1',
    claims: 0,
    at: new Date(),
  });
  await setDoc(doc(db, 'friendCodes', 'WXYZ6789'), {
    ownerDevice,
    claims: 29,
    at: new Date(),
  });
  await setDoc(doc(db, 'friendCodes', 'WXYZ6788'), {
    ownerDevice,
    claims: 30,
    at: new Date(),
  });
  await setDoc(doc(db, 'friendClaims', 'd'.repeat(64)), {
    code,
    device: 'd'.repeat(64),
    at: new Date(),
  });
});

const friend = testEnv.authenticatedContext('friend-1').firestore();
const owner = testEnv.authenticatedContext('owner-1').firestore();
const stranger = testEnv.authenticatedContext('stranger-1').firestore();

await check('claim and increment succeed together', async () => {
  await assertSucceeds(
    runTransaction(friend, async (tx) => {
      const codeRef = doc(friend, 'friendCodes', code);
      const claimRef = doc(friend, 'friendClaims', friendDevice);
      const snap = await tx.get(codeRef);
      tx.update(codeRef, {
        claims: snap.data().claims + 1,
        lastClaimDevice: friendDevice,
        lastClaimUid: 'friend-1',
      });
      tx.set(claimRef, {
        code,
        device: friendDevice,
        authUid: 'friend-1',
        at: serverTimestamp(),
      });
    }),
  );
});

await check('owner can read the new claim and a stranger cannot', async () => {
  await assertSucceeds(getDoc(doc(friend, 'friendClaims', friendDevice)));
  await assertFails(getDoc(doc(stranger, 'friendClaims', friendDevice)));
});

await check('legacy claim without authUid stays readable', async () => {
  await assertSucceeds(getDoc(doc(stranger, 'friendClaims', 'd'.repeat(64))));
});

await check('a claim without the counter increment is denied', async () => {
  await assertFails(
    setDoc(doc(friend, 'friendClaims', otherDevice), {
      code,
      device: otherDevice,
      authUid: 'friend-1',
      at: serverTimestamp(),
    }),
  );
});

await check('an increment without a new claim is denied', async () => {
  await assertFails(
    updateDoc(doc(friend, 'friendCodes', code), {
      claims: 2,
      lastClaimDevice: otherDevice,
      lastClaimUid: 'friend-1',
    }),
  );
});

await check('authUid cannot impersonate another user', async () => {
  await assertFails(
    runTransaction(friend, async (tx) => {
      const codeRef = doc(friend, 'friendCodes', 'WXYZ6789');
      const claimRef = doc(friend, 'friendClaims', otherDevice);
      const snap = await tx.get(codeRef);
      tx.update(codeRef, {
        claims: snap.data().claims + 1,
        lastClaimDevice: otherDevice,
        lastClaimUid: 'friend-1',
      });
      tx.set(claimRef, {
        code: 'WXYZ6789',
        device: otherDevice,
        authUid: 'stranger-1',
        at: serverTimestamp(),
      });
    }),
  );
});

await check('the code owner cannot claim their own code', async () => {
  await assertFails(
    runTransaction(owner, async (tx) => {
      const codeRef = doc(owner, 'friendCodes', code);
      const claimRef = doc(owner, 'friendClaims', otherDevice);
      const snap = await tx.get(codeRef);
      tx.update(codeRef, {
        claims: snap.data().claims + 1,
        lastClaimDevice: otherDevice,
        lastClaimUid: 'owner-1',
      });
      tx.set(claimRef, {
        code,
        device: otherDevice,
        authUid: 'owner-1',
        at: serverTimestamp(),
      });
    }),
  );
});

await check('the 31st claim is denied', async () => {
  await assertFails(
    runTransaction(stranger, async (tx) => {
      const codeRef = doc(stranger, 'friendCodes', 'WXYZ6788');
      const device = 'e'.repeat(64);
      const claimRef = doc(stranger, 'friendClaims', device);
      const snap = await tx.get(codeRef);
      tx.update(codeRef, {
        claims: snap.data().claims + 1,
        lastClaimDevice: device,
        lastClaimUid: 'stranger-1',
      });
      tx.set(claimRef, {
        code: 'WXYZ6788',
        device,
        authUid: 'stranger-1',
        at: serverTimestamp(),
      });
    }),
  );
});

await check('claim 30 of 30 is allowed on a legacy code', async () => {
  const device = 'f'.repeat(64);
  await assertSucceeds(
    runTransaction(stranger, async (tx) => {
      const codeRef = doc(stranger, 'friendCodes', 'WXYZ6789');
      const claimRef = doc(stranger, 'friendClaims', device);
      const snap = await tx.get(codeRef);
      tx.update(codeRef, {
        claims: snap.data().claims + 1,
        lastClaimDevice: device,
        lastClaimUid: 'stranger-1',
      });
      tx.set(claimRef, {
        code: 'WXYZ6789',
        device,
        authUid: 'stranger-1',
        at: serverTimestamp(),
      });
    }),
  );
});

await testEnv.cleanup();

if (failed > 0) {
  console.error(`${failed} rule check(s) failed`);
  process.exit(1);
}
console.log('firestore rules ok');
