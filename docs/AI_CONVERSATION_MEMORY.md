# AI conversation memory

The assistant previously saved and displayed messages but sent only a system prompt and the latest user message to the proxy. Follow-up questions that referenced an earlier exchange therefore arrived without that exchange.

## Request and persistence

Each chat request contains the existing SmartSave system instructions, current financial context read from the active account's repository, recent complete user and assistant turns in chronological order, and the latest user message exactly once. Historical messages retain their original roles and languages. The current language instructions still let the user ask for an answer in a different language. The proxy, Firebase token handling and OpenRouter model configuration are unchanged.

The existing account database stores the transcript and selected conversation ID. The assistant reads previous list-format snapshots and accepts both `content` and older `text` message fields. Recognizable legacy offline replies are marked as local on read. Older unmarked replies whose provenance cannot be inferred retain their previous assistant role. An unreadable snapshot stays in place and is not overwritten.

All assistant screens in the account scope use one transcript store and one active generation. Beginning a request takes a stable snapshot before the latest user message is added. The user message is saved separately from provider success. The completed reply is appended to the same conversation. Incomplete streamed text exists only in UI state. Failed requests leave an unanswered user message in the transcript. Retry on that screen uses the same message and does not append another copy. Local fallback replies are saved with a provenance marker and excluded with their corresponding prompts from subsequent provider history. Starting a new conversation sets no active transcript until a message is sent.

The account's existing repository and mobile SQLCipher behavior continue to govern storage. Local database encryption does not cover the copy of each selected turn sent to the authenticated HTTPS proxy and OpenRouter. No secondary chat store or additional plaintext file is created. The existing export and account deletion policies still apply.

## History window

The default input allowance is 14,000 UTF-8 bytes, including the system prompt and a fixed 32-byte accounting allowance per message. `SMARTSAVE_AI_INPUT_BYTES` can configure the input target between 10,000 and 20,000 bytes. The financial context is capped at 3,000 bytes, the latest prompt at 5,000 bytes subject to the remaining budget, and the provider retains its existing 2,000 output-token limit. Truncation respects UTF-8 character boundaries and inserts a marker in the provider payload. The complete text remains in local history.

Previous complete turns are selected newest first and then sent in chronological order. Once a complete turn exceeds the available budget, older turns stay in SQLite and are omitted from that request. This is a conservative payload budget, not a tokenizer or a guarantee about the active model's context limit. There is no summary, embedding store or cross-conversation recall.

## Verification

The Flutter regressions inspect the actual Dio request payload for an ETF example, a Russian follow-up, a Kazakh follow-up, and English recall after reopening the account database. They exercise a separate conversation, a second account, retry after an incomplete stream, and local fallback exclusion. A widget test verifies the reopened chat sends its prior Unicode and Markdown content with the next message. Context tests cover byte limits and safe truncation. A proxy regression verifies the exact multilingual message array forwarded to OpenRouter.

Locked dependency resolution and analyzer checks exited 0 with zero analyzer diagnostics. The full Flutter suite passed 60 tests with coverage. The focused proxy and chat suite passed 10 tests. The Node backend suite passed 31, Firestore rules passed 9, and the Auth and Firestore lifecycle passed 1. Gitleaks and the Git whitespace check exited 0. Provider responses were mocked.

Live OpenRouter conversational memory is unverified. On the approved hosted endpoint, sign in as a disposable account with fictional records. Ask for an ETF versus stock example with specific numbers, request the same example in Russian and Kazakh, then reopen the same conversation and ask what the first question was. Check that the response retains the earlier topic and numbers. Start a new chat and verify that it has no knowledge of the previous chat. Log out and sign in as a second disposable account and verify the original conversation is unavailable. Do not include tokens or private financial records in the verification notes.
