# SmartSave capstone demo

Use a mobile build, an isolated Firebase project with Email/Password and Firestore configured, and a disposable, verified account you control. Sign in on the presentation device and confirm onboarding before presenting. Use a separate test account for the ownership check. Keep real account data, tokens, exported JSON, and private Firebase configuration off screen. The sample card setup requests no bank credentials.

| Screen | Demonstration using fictional data | Expected result |
| --- | --- | --- |
| Welcome and authentication | Register with the disposable inbox, verify the email, and sign in. Complete onboarding and choose **Skip, add transactions manually** on the sample card screen. | Access the signed-in dashboard after onboarding. |
| Home and goals | Create “Capstone laptop” with a ₸350,000 target, open it, and use **Add money** to record ₸35,000. | The goal shows ₸35,000 saved and 10% progress. The contribution is a record only. |
| Transactions and budget | Enter a ₸2,500 expense named “Fictional lunch”. Review the recent list and the category budget under spending analytics. | The expense appears in the list and contributes to the recorded month's category total. |
| Deposits | Browse and filter the sample deposit catalogue. | Rates are illustrative. The calculator leaves account balances unchanged. |
| Invest | Open Investment Intelligence, enter a fictional thesis and threshold, evaluate manually entered dated evidence, and reopen assessment history. | Assessment labels reflect the entered condition and evidence. The app does not verify the underlying market facts. |
| AI | Ask about expenses or the laptop goal. Where the test proxy is configured, verify online status, watch a response arrive, then reopen the conversation. | Online streaming depends on proxy, provider, and quota availability. The offline label indicates local rule-based help. Treat all guidance as educational. |
| My Account and privacy | Open **Privacy & data**, choose **Export local data**, and preview the test account's JSON. Close the preview without copying it. | The export contains that account's records. Exported data can be sensitive plaintext. |
| Sign out and return | Sign out, sign back in as the same test user, and check the saved records. Switch to the second test account and confirm those records are absent. | Financial data stays associated with the account that owns it. |
| Optional sync | Rehearse on two devices against the same isolated Firebase project before including this step. Use the same verified test account and check that one supported record propagates after reconnect. | Include the step only after it succeeds on the target setup. A passing emulator test or native compilation alone does not establish this result. |

If OpenRouter is unavailable or rate-limited, switch to the labeled offline helper and ask about the locally saved expense or goal. Verify that the backend URL is reachable from the device, that its project matches the Firebase token, and that the provider has quota. For a broader network outage, rehearse with an already signed-in local session. Email verification and fresh sign-in require Firebase connectivity. Keep a labeled recording of the test flow available if the signed-in session fails. Identify recorded, offline, and live segments as they are presented.

Verify the target phone's keyboard, scroll, and Back behavior during rehearsal. Keep account deletion out of the demonstration. For release limitations and the native test procedure, see [Stage 6.5 verification](STAGE_6_5_RELEASE_BLOCKERS.md).
