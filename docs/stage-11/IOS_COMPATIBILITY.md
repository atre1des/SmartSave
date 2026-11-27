# Stage 11A — iOS compatibility and build preparation

## Status

Base was `experimental/ios-redesign-with-avatars` at `6a2b528589ffe060c87f78bb6487cb86329dc59b`. PR #10's head matched that commit and remote `development` was still `f1ed26e266e4ee17f69a7b164b2f2d59f9844d8d`.

Local validation uses Debian Linux, Flutter 3.41.7 and Dart 3.11.5. Neither Xcode nor the Android SDK is installed here. **iOS compilation, simulator execution, iPhone verification and live Firebase checks remain pending.** The dedicated cloud workflow builds and packages an unsigned iOS Simulator app. A green build would verify compilation and packaging, while runtime checks still require launching the app. See the [Windows and Appetize runbook](IOS_CLOUD_BUILD.md).

## Native project audit

| Area | Observed configuration and outstanding checks |
| --- | --- |
| Runner and Xcode | The Runner project uses a shared Runner scheme and iOS 13.0 minimum. Swift AppDelegate registers generated plugins through the implicit Flutter engine, with FlutterSceneDelegate configured in the app plist. Check launch, lifecycle and iPhone/iPad orientation on Xcode. |
| Native dependency resolution | Added the Flutter 3.41.7 CocoaPods template with iOS 13.0 and linked Debug, Profile and Release xcconfigs. FlutterFire resolves Firebase Apple SDK 11.15.0. Firebase plugins, shared preferences and Darwin secure storage declare iOS 13. SQLCipher declares iOS 11 and pins SQLCipher 4.10.0 through the plugin podspec, with FMDB/SQLCipher 2.7.x. Resolve the full pod graph on a Mac. No native lockfile has been generated or verified in this checkout. |
| Firebase client | Runtime initialization calls native Firebase defaults. The existing iOS plist and FlutterFire options specify Firebase project `smartsave-dev-3a1f5` and bundle ID `com.example.smartSave`. The plist was present on disk but absent from Runner resources. It is now included in Copy Bundle Resources. The hosted XCTest checks the bundled plist and identifier. Apple signing and the Firebase Console registration were not authenticated in this audit. |
| Permissions and entitlements | Runner declares no camera, photos, location or notifications permission. Avatars ship as SVGs. Export copies the selected data to the clipboard. No ATS-wide bypass, Associated Domains or custom URL scheme is configured. The same Runner entitlements file is configured for all build modes and declares an empty Keychain access-group list. Verify default Keychain access in the signed device build. |
| Local database and Keychain | The iOS path selects native SQLCipher, uses a separate database per Firebase UID, and stores a per-account random key through Darwin secure storage. It verifies the stored key and fails if the encrypted database exists without its key. Linux repository tests use FFI and cannot establish native encryption. On a disposable iOS account, create records, force-quit, relaunch, and confirm they reopen. On a simulator inspect the fixture database header using the command below. Test switching accounts and deleting the disposable account. |
| Network and AI | The app sends a Firebase ID token to the configured HTTPS proxy and disables redirects on the authenticated transport. Debug loopback defaults apply only to local development. iPhone loopback is the phone itself. Supply `SMARTSAVE_BACKEND_URL` for device testing and account deletion. Leave ATS enabled and serve a trusted certificate. |
| App icons, launch, privacy | AppIcon slots are present with matching image dimensions, including an opaque 1024 px image. The native launch storyboard uses a white background and transparent 1 px placeholder images. Review the icon and light/dark cold-start transition on hardware before distribution. Review the aggregated Apple privacy manifests from the resolved build and App Store disclosures before signing a distribution release. |

## Firebase Console and authentication

1. In Firebase Console, open **Project settings → General → Your apps** for `smartsave-dev-3a1f5`. Select the iOS app and verify its Apple bundle ID is exactly `com.example.smartSave`. Download its `GoogleService-Info.plist` if the checked-in client config is stale, replace `ios/Runner/GoogleService-Info.plist` locally, and make sure Runner still lists it under **Build Phases → Copy Bundle Resources**.
2. If Xcode signing requires a new bundle ID, first confirm the team-approved identifier. In the same Firebase project select **Add app → iOS**, register that exact bundle ID, download its plist and update the Runner bundle identifier for Debug, Profile and Release in Xcode. Refresh only the iOS Firebase options if the project begins using explicit options. Keep the plist and identifiers consistent. A Firebase client plist is not an Admin credential. Store service accounts, signing keys and passwords outside the repository.
3. In **Authentication → Sign-in method**, confirm **Email/Password** is enabled. In **Authentication → Templates**, review verification and password-reset sender and action links. Check the intended authorized domains in **Authentication → Settings → Authorized domains** if using a custom action handler. SmartSave currently uses Firebase-hosted browser links and the in-app **I've verified my email** action to reload the Firebase user. Password reset is also completed in the browser. It does not currently need an iOS universal link, OAuth URL scheme, or Firebase Dynamic Links.
4. In **Firestore Database → Rules**, verify the deployed rules enforce the UID owner under `/users/{uid}` and match the intended checked-in rules. Stage 11A performs no rules deployment. Use two disposable users and verify that each sees only their own records when signing out and back in.
5. For account deletion confirm the HTTPS backend uses the same Firebase project and its authenticated `/api/account/delete-data` route is configured. Exercise reauthentication, pending-sync protection, remote deletion, local cleanup and sign-out with a disposable user only. Verify that a failed remote deletion preserves local data.

## Flutter interface audit

| Screen | Static and shared test findings | Native checks still needed |
| --- | --- | --- |
| Welcome, sign-in, registration, verification and reset | Shared auth layout uses SafeArea and a scrollable viewport. Its iOS-platform widget test exercises notch padding, scrolling the focused form with a keyboard inset, and left-edge back. Existing tests cover registration, verification and localized reset with mocked services. | Test real keyboard, password AutoFill, VoiceOver and external verification/reset round trips. |
| Home | SafeArea and a scrollable body account for floating navigation. Regression tests cover Quick Actions, right-aligned Recent amounts and narrow localized layouts. | Check status bar, floating tab bar and home indicator with both appearances and landscape. |
| Transactions and budgets | Transaction list/detail/editor and spending/budget pages use scrollable content. The shared flow exercises transaction creation and budget editing. | Check numeric keyboard and dismissal, bottom editor sheet reachability, and category/amount layout at accessibility sizes. |
| Deposits and goals | Lists, comparisons, goal editor and contribution flows use SafeArea and scrollable bodies. Existing financial tests exercise deposit filters and goal contributions. | Check calculator controls, date picker, and modal dimensions on iPhone and iPad. |
| AI Assistant and history | The composer observes the keyboard via Scaffold and the shell hides the tab bar when the AI keyboard is open. History uses a safe-area sheet. Mocked AI tests cover streaming, reuse of conversation context and history. | Verify editor focus, dictation and stream scrolling over the configured HTTPS proxy. Test foreground/background and a weak network. |
| Investment tools | Tool tabs use SafeArea/scrolling. Lesson and portfolio editors account for keyboard insets in scrollable sheet content. The research test exercises thesis creation and assessment history. | Check the numeric keyboard, selector labels, chart clipping at large text, and gesture navigation. |
| Profile and My Account | Profile controls are scrollable, with shared settings and auth behavior. The account journey covers appearance, language, export and sign-out. | Verify keyboard, clipboard handling, appearance persistence and account switching on the signed app. |
| Animal avatar picker | Rounded, safe-area sheet with scrollable adaptive grid. Tests cover local persistence, reset and account isolation at compact widths in both themes. | Check VoiceOver focus, selected state announcements, bottom safe area and swipe-to-dismiss. |

## Reproduce on macOS

Install a supported full Xcode with an iOS Simulator runtime, CocoaPods on your PATH, and Flutter **3.41.7 stable**. Complete Xcode's license and first-launch setup. Use the existing HTTPS proxy URL approved for the Firebase project.

```bash
git fetch origin refs/heads/stage-11/ios-compatibility
git switch -c ios-local-validation FETCH_HEAD
flutter --version
xcodebuild -version
pod --version
flutter doctor -v
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build ios --simulator --debug --no-codesign
/usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' \
  build/ios/iphonesimulator/Runner.app/GoogleService-Info.plist
open -a Simulator
xcrun simctl list devices booted
```

Flutter runs CocoaPods as part of the build. If CocoaPods reports stale resolution metadata, run `(cd ios && pod install --repo-update)` after Flutter has produced `ios/Flutter/Generated.xcconfig`, then rerun the build. Open `ios/Runner.xcworkspace` in Xcode. With an eligible simulator booted, run the hosted XCTest with the simulator UUID:

```bash
SIMULATOR_ID='<booted simulator UUID>'
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -only-testing:RunnerTests/RunnerTests/testFirebaseClientConfigurationIsBundledForRunner
```

For an iPhone, connect and trust the Mac, enable Developer Mode, and select the device and your development Team in **Runner → Signing & Capabilities**. Use the registered bundle ID and let Xcode manage development signing. If automatic signing cannot register the ID, the Apple team must grant access or supply an alternative team-owned ID to register in Firebase first.

```bash
flutter devices
IOS_DEVICE='<iPhone device ID from flutter devices>'
export SMARTSAVE_BACKEND_URL='https://<approved-proxy-host>'
flutter run -d "$IOS_DEVICE" --dart-define=SMARTSAVE_BACKEND_URL="$SMARTSAVE_BACKEND_URL"
```

Use the same command with the simulator ID for integration smoke tests. After creating fictional records in a simulator and relaunching successfully, check that the encrypted database exists and does not start with the unencrypted SQLite signature:

```bash
container=$(xcrun simctl get_app_container "$SIMULATOR_ID" com.example.smartSave data)
find "$container" -name 'smartsave_account_*.encrypted.db' -exec od -An -tx1 -N16 {} \;
```

An opaque header alone is insufficient. Pair it with successful reopening on the same account and isolation on a second one. Check the screen matrix above in light and dark, in EN/KK/RU, and with large accessibility text. Record the simulator model, runtime, Xcode version and physical iPhone model in the next verification report.

References: [Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup) · [Firebase Apple setup](https://firebase.google.com/docs/ios/setup) · [Firebase action handlers](https://firebase.google.com/docs/auth/custom-email-handler)
