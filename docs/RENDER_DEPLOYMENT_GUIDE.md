# Deploy the SmartSave AI proxy on Render Free

The Render service runs the existing Express proxy. The mobile app uses it over HTTPS, so a development computer can be turned off after deployment. Render access and an approved OpenRouter key are required to complete live verification.

## Create the web service

1. After the Stage 8 branch is reviewed and merged, sign in to Render and select **New → Web Service**. Connect the GitHub repository `atre1des/SmartSave`. Select **Public Git Repository** or grant Render access through its GitHub integration as appropriate.
2. Use the settings below. The repository's `render.yaml` records the same service definition. If importing it as a Blueprint instead, select Free and add the Firebase secret file separately before relying on the deployment.
3. Set the environment variables and upload the Firebase secret file in the service's **Environment** page. Keep automatic deployments disabled and trigger the first deployment manually after the settings have been checked.

| Setting | Value |
| --- | --- |
| Branch | `development` after merge |
| Root Directory | `backend` |
| Language and runtime | Node, `NODE_VERSION=24.22.3` |
| Build Command | `npm ci --omit=dev` |
| Start Command | `npm start` |
| Instance Type | Free |
| Health Check Path | `/health` |
| Auto Deploy | Off |
| Host and port | The app binds to `0.0.0.0` using Render's injected `PORT` |

## Environment and secrets

| Name | Where and what to set |
| --- | --- |
| `OPENROUTER_API_KEY` | Paste the approved key into the Render environment settings. Keep it out of Git, Flutter configuration, and logs. |
| `OPENROUTER_MODEL` | Set the intended supported free model, for example the existing default `baidu/ernie-5.5-flash-preview:free`. Check that the model is available to the test account before relying on it. The backend rejects paid model IDs. |
| `FIREBASE_PROJECT_ID` | Use the exact project configured in the Flutter test build. |
| `GOOGLE_APPLICATION_CREDENTIALS` | Set `/etc/secrets/firebase-admin.json`. In **Secret Files**, upload a dedicated Firebase Admin service-account JSON as `firebase-admin.json`. Use an account approved by the project owner and avoid broad project-wide administrator roles. |
| `SMARTSAVE_ALLOWED_ORIGINS` | Leave empty for native-only clients. For web, set a comma-separated list of exact front-end origins with scheme and optional port. Omit paths, trailing slashes, and wildcards. |
| `SMARTSAVE_ENABLE_ACCOUNT_DELETION` | Set `false`. Render and production runtime settings also prevent activation through this flag. |
| `OPENROUTER_FALLBACK_MODEL` | Optional existing metadata setting. The proxy does not automatically switch to it. |

Render supplies `RENDER=true`. Keep emulator host variables out of that environment. Startup validates the key's presence and the mounted Firebase credential format and project. The check cannot establish that the upstream accepts the key or that the service account remains valid. Use the server-side key only through Render secret management. Rotate exposed keys or service-account material in the respective provider and remove the old credential.

For local development, run `npm --prefix backend ci` and `npm --prefix backend start`. The server still reads an untracked `backend/.env` locally and can use Firebase Application Default Credentials. Debug Android emulators still default to `http://10.0.2.2:3001`.

## Verify the hosted endpoint and app

1. Copy **the actual HTTPS origin** shown on the Render service page. Set `SMARTSAVE_PROXY_URL` in your shell to this origin. Verify that the endpoint presents a valid TLS certificate and responds with `status: ok` and the expected model. Allow time for the first wake.
2. Confirm that the protected endpoint rejects an unauthenticated request with HTTP 401. This smoke check sends no user data or token.
3. Run Flutter with the same Firebase project configured on the device. Register or sign in with a disposable Firebase account, complete email verification, and use fictional financial records. Send a harmless prompt and watch the reply render progressively. Reopen the conversation, verify the reply persists, and record the deployed commit, selected model, and observed result without recording tokens.
4. Verify a release build with the same define on Android and iOS. For a future web build, use an exact HTTPS origin allowlist and configure the Flutter web client for the same Firebase project. The Render setup covers the proxy API. Web Firebase initialization and browser app compatibility still require separate verification. The current Dio browser adapter buffers the response until completion, so progressive browser rendering requires additional client work. Native clients can consume SSE incrementally.

```sh
curl --fail --max-time 85 "$SMARTSAVE_PROXY_URL/health"
curl --silent --show-error --max-time 85 --output /dev/null --write-out '%{http_code}\n' \
  --request POST "$SMARTSAVE_PROXY_URL/api/chat/completions"
flutter run --dart-define=SMARTSAVE_BACKEND_URL="$SMARTSAVE_PROXY_URL"
flutter build apk --release --dart-define=SMARTSAVE_BACKEND_URL="$SMARTSAVE_PROXY_URL"
flutter build ios --release --dart-define=SMARTSAVE_BACKEND_URL="$SMARTSAVE_PROXY_URL"
```

Run the iOS build on macOS with the project's usual signing configuration. In PowerShell, use `$env:SMARTSAVE_PROXY_URL` for the value and `curl.exe` to use curl. Only the public HTTPS origin belongs in the Dart define.

## Cold starts and troubleshooting

Render Free may sleep during inactivity. Flutter displays a connecting state while checking liveness and can make a second HTTPS health request on a transient gateway failure, timeout, connection error, or a wake page. Each attempt has a 38-second budget and the retry waits one second. The app does not retry chat POSTs automatically. After the wait expires it offers its local fallback. The next question can try the proxy again.

- **401 from Firebase** means the proxy failed to verify the session. Check the project ID and sign in again. A distinct OpenRouter 401 points to the proxy's OpenRouter credentials.
- **403** can indicate an upstream key or model permission problem. If a browser blocks the request at preflight, check the exact origin and inspect the response headers without copying any Authorization values.
- **429** can come from SmartSave request limits or OpenRouter quota. Observe `Retry-After` when provided and distinguish daily quota from temporary throttling.
- **503 or Render startup failure** calls for checking the deploy logs, the secret-file name and path, and the project and key settings. A healthy endpoint confirms liveness only.
- **Streaming failure or timeout** calls for checking for `text/event-stream`, incremental output, and a terminal `[DONE]` event from OpenRouter. The proxy disables buffering where supported, stops upstream work when the client disconnects, and bounds the upstream request at 120 seconds. A partial response or health check alone does not verify successful generation.

## Roll back

In Render, select the last verified deploy from **Events** and use **Rollback** if available for the service. Otherwise manually deploy the last verified Git commit using the existing service settings. Verify that this revision supports the configured secret file and compatible client settings, then recheck health, 401 enforcement, and one authenticated stream with a disposable account. If the service must be taken offline, suspend it in Render and use local development or the assistant's local fallback.
