# SmartSave iOS Simulator builds from Windows

The workflow builds on GitHub's `macos-15` runner, with Flutter **3.41.7 stable** and the runner's preinstalled Xcode and CocoaPods. Each run prints the exact host architecture, Xcode, simulator SDK, and CocoaPods versions. The output is an unsigned simulator bundle. Apple Developer Program membership and distribution signing are unnecessary for this workflow.

## Start or find a build

1. Open [SmartSave iOS Simulator in GitHub Actions](https://github.com/atre1des/SmartSave/actions/workflows/ios-simulator.yml) and select the latest run for **stage-11/ios-cloud-build**.
2. The branch push starts a run. GitHub only offers **Run workflow** after the workflow file is present on the repository's default branch. When that becomes available, choose **stage-11/ios-cloud-build** from the branch selector. In the meantime, on an existing run select **Re-run jobs → Re-run all jobs** if you have permission.
3. In the run, expand **Build and package unsigned simulator app**. A successful build has passed Flutter analysis and tests, compiled the simulator target, verified the bundled Firebase configuration, and uploaded an artifact. If it fails, use the log from the first failing step. The **Verify and package Runner.app** step reports the binary architectures.

The optional GitHub Actions repository variable **SMARTSAVE_BACKEND_URL** must be a public, trusted HTTPS origin. It defaults to `https://smartsave-sl61.onrender.com`. Change it under **Settings → Secrets and variables → Actions → Variables** and rerun the workflow if your team uses a different proxy. The endpoint is compiled into the app. API keys and service-account credentials belong on the backend.

## Download and upload to Appetize

1. After a successful run, scroll to **Artifacts** and download **SmartSave-iOS-Simulator**. GitHub downloads an outer archive named `SmartSave-iOS-Simulator.zip`.
2. In Windows Explorer select **Extract All** on the outer archive. Keep the extracted **SmartSave-iOS-Simulator.app.zip** intact. That archive contains `Runner.app` and its resources. Upload the inner archive, rather than GitHub's outer archive.
3. Sign in to [Appetize](https://appetize.io/), open the dashboard and choose the upload or new build action. Select **iOS** where prompted and upload **SmartSave-iOS-Simulator.app.zip**. Wait for processing and open the new build's preview or launch link.
4. Choose an offered iPhone model and start the session in the browser. Simulator platform and Firebase bundle matching are checked during packaging. Appetize startup and its supported host architecture must still be confirmed with the uploaded artifact.

## Runtime smoke test with disposable data

- Check Welcome and both appearances. Register a disposable account and complete the Firebase email-link verification in a separate browser tab, then return to SmartSave and tap **I've verified my email**. Check sign-in, password reset and sign-out.
- Add a fictional transaction, goal and contribution. Relaunch the app in the same simulator session to check records and avatar persistence. Exercise sign-out and account switching with a second disposable user. A fresh hosted session can have a new sandbox.
- Check Firestore sync and UID isolation. Confirm AI can receive a streamed response over the configured HTTPS proxy. Inspect signed-in connection errors separately from build issues.
- Check EN/KK/RU, Home Quick Actions, Recent Transactions, dark mode, picker safe areas, and keyboard dismissal. Test deletion only with a disposable account.
- Appetize is a simulator. Real iPhone Keychain behavior, provisioning, device performance and hardware-specific UI still need device verification.

The repository already contains an iOS Firebase client plist for the configured bundle ID. The iOS audit lists the exact Firebase Console checks and replacement path if the registration changes. No live Firebase sign-in, Firestore operation or Appetize session is established by a successful compilation. [Firebase and iOS compatibility audit](IOS_COMPATIBILITY.md)
