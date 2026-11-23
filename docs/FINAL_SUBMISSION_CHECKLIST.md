# SmartSave final submission checklist

## Repository and configuration

- [x] Stage 6.5 baseline recorded as `fa3c9a913a05f072573e1b5e1e85930e743455be`.
- [x] Demo instructions and setup documented in the [demo guide](FINAL_DEMO_GUIDE.md) and [README](../README.md).
- [ ] Restore the locked Flutter dependencies under Flutter 3.41.7 and Dart 3.11.5 on the presentation machine. Install Node.js 22 and run `npm --prefix backend ci` for backend work.
- [ ] Confirm Android SDK and JDK 17, or Xcode and CocoaPods on macOS. Install the mobile build on the target device.
- [ ] Confirm the isolated Firebase project, platform configuration, verified demo accounts, and Firestore rules. Configure the proxy with the same project ID, approved Firebase Admin credentials, a device-reachable URL, and a server-side OpenRouter key for an online AI demo.
- [ ] Check the Stage 7 PR's Android debug and unsigned iOS builds and rehearse on the presentation device. Stage 6.5 compiled both platforms in CI. See the [baseline run](https://github.com/atre1des/SmartSave/actions/runs/45230959418).
- [ ] Supply the final report, slides, labeled screenshots or recording, contributor credits, and repository or artifact links required by the course. Keep identifiers for personal accounts and plaintext exports off screen.

## Evidence boundaries

The Stage 7 Linux run resolved the Flutter lockfile, reported zero analyzer diagnostics, and passed 48 Flutter tests with 47.8% line coverage in the generated LCOV report. The backend passed 23 tests, the Firestore rules emulator passed 9, and the Auth/Firestore lifecycle emulator passed 1. The compact widget run covered mock registration and email verification, onboarding, a goal contribution, a transaction, budget review, investment and AI navigation, export preview, and returning to the saved transaction after signing in again.

Flutter widget tests use mocked or local services and SQLite on Linux. Backend tests simulate upstream OpenRouter responses. Firebase emulator tests exercise Auth/Firestore lifecycle and authorization, while device tests must establish actual Flutter-to-Firestore transport and encrypted storage behavior. Native compilation does not establish those runtime properties. Use the [Stage 6.5 report](STAGE_6_5_RELEASE_BLOCKERS.md) for device instructions and the [Stage 6 report](STAGE_6_VERIFICATION.md) for the broader evidence.

## Open release blockers

| Severity | Blocker and evidence still required |
| --- | --- |
| Critical | Verify SQLCipher migration, key recovery, and encrypted-file cleanup on Android and iOS with disposable fixtures. |
| Critical | Recover retained plaintext backups only in a controlled process. Establish owner authorization and confirm recovery before any disposal. |
| Critical | Preserve legacy shared records without automatic claims. Independent ownership provenance is still required. |
| High | Validate Flutter-to-Firestore sync, offline writes, reconnect, and account isolation on native devices against an isolated project. |
| High | Verify combined encrypted local and cloud deletion using disposable accounts and approved test infrastructure, including confirmation and recovery from failure. Keep production deletion disabled. |
| High | Triage unsupported historical queue entries and per-record history. Preserve data until its ownership and recovery path are known. |

Publication for capstone review is separate from production release approval. The demonstration requires isolated test data and a target-device rehearsal.
