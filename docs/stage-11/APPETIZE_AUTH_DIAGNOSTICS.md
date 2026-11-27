# Diagnose Firebase email sign-in on Appetize

## What the source and build establish

The iOS plist and the iOS entries in `lib/firebase_options.dart` agree on the Firebase project, app ID, API key, sender ID and bundle identifier. The project is `smartsave-dev-3a1f5` and the Runner bundle ID is `com.example.smartSave` in Debug, Profile and Release. The simulator workflow checks the bundle identifier of the packaged plist.

Startup calls `Firebase.initializeApp()` using the native defaults. On iOS, the bundled `Runner.app/GoogleService-Info.plist` supplies those defaults. The generated Dart options are a cross-check for this startup path. Firestore initializes afterward. Signing in then calls Firebase Auth's email/password method and reloads the returned user to refresh verification state. The Firebase user stream can switch account screens as soon as credentials are accepted, before reload finishes.

The simulator compilation and the user's successful launch do not identify the sign-in exception. The cloud workspace has no authenticated Appetize session or runtime transcript. The production root cause is unconfirmed.

## Reproduce with the debug simulator artifact

Upload the latest `SmartSave-iOS-Simulator.app.zip` to Appetize. Start a fresh iOS simulator session with the new build. Try a disposable verified user in the same Firebase project. Compare with Android using that same user and project if possible.

The updated debug build uses the localized error message and adds a phase plus a safe Firebase code while the sign-in screen is present. For a later failure, use the simulator's app/device log view if available and filter for `[FirebaseAuth]`:

- `signInWithEmailAndPassword / …` means the credentials call threw before a user reload.
- `signInWithEmailAndPassword succeeded` followed by `reloadAfterSignIn / …` means Firebase accepted the credentials and the follow-up failed. The user-stream transition may already have moved away from the sign-in screen.
- Two success markers mean both Firebase calls returned. Diagnose the next screen or account initialization separately.

The marker includes the target platform and known SDK code only. Codes outside the allowlist are reported as `unrecognized-firebase-code`. Exception messages, credentials, tokens and user identifiers are intentionally excluded. Share only the marker and which screen it appeared on. The tests simulate both phases and verify the emitted details. They do not reproduce the hosted Appetize session.

## Check only what the marker points to

| Marker | Check |
| --- | --- |
| `invalid-credential`, `wrong-password`, `user-not-found`, `user-disabled` | Verify the account is in **Firebase Console → Authentication → Users** for the intended project, that it has a password provider, and that the account is enabled. With email-enumeration protection, invalid credentials can cover several account/password cases. |
| `operation-not-allowed`, `configuration-not-found` | Check **Authentication → Sign-in method → Email/Password** and the iOS app entry under **Project settings → Your apps**. |
| `invalid-api-key`, `api-key-not-valid`, `app-not-authorized` | Verify the current plist came from the registered iOS app. In Google Cloud **APIs & Services → Credentials**, review the actual iOS client key restrictions, matching bundle ID and allowed Auth APIs. Preserve the project's security restrictions. |
| `network-request-failed` | Check Appetize session outbound networking and any account-level allowlist or proxy. Firebase email/password needs Google Identity Toolkit and Secure Token HTTPS access. Compare a fresh hosted session against Android or another simulator. The Render AI endpoint is independent of Firebase sign-in. |
| `keychain-error`, `internal-error` | Retest in a fresh simulator session. Compare against a simulator under Xcode to separate hosted simulator behavior from iOS-wide behavior. Retain only the safe phase/code in reports. |
| `too-many-requests` or `quota-exceeded` | Check Firebase Auth quota and throttling before retrying. |

Email/password sign-in does not use iOS phone-auth APNs or reCAPTCHA setup. Email verification and password reset use browser links. This change leaves Firebase registration, rules, refresh behavior and transport settings in place.
