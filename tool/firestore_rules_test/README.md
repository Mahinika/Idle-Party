# Friend-claim rules tests

Runs `firestore.rules` against the local Firestore emulator. No paid service
and no deploy.

```bash
cd tool/firestore_rules_test
npm install
npm test
```

`npm test` starts the Firestore emulator from the repo `firebase.json` and
loads `firestore.rules`. It does not deploy.

Needs Node and a JDK. The first run downloads the emulator. Java 21 is enough.
The project id is `demo-idle-party` so the emulator does not need credentials.
