// Automated tests for the SmartSave backend AI proxy (server.js).
//
// Safety guarantees:
// - global.fetch is stubbed; requests to openrouter.ai NEVER leave this process.
// - server.js is imported in-process on an EPHEMERAL port (never 3001) and
//   closed when the suite finishes. No persistent backend server is started.
// - The API key used is an obvious dummy. backend/.env is never read or
//   printed: the dummy is set before server.js loads, and dotenv does not
//   override existing environment variables.

import { test, beforeEach, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import net from 'node:net';

const FREE_PRIMARY = 'baidu/ernie-5.5-flash-preview:free';
const FREE_SECONDARY = 'nvidia/nemotron-3-ultra-550b-a55b:free';
const DUMMY_KEY = 'test-dummy-key-not-a-real-secret';
const FAKE_LEAKED_KEY = 'sk-or-v1-' + 'a'.repeat(40);

const realFetch = global.fetch;
const realListen = http.Server.prototype.listen;
const realConsoleError = console.error;

let server = null;
let baseUrl = '';
let upstreamCalls = [];
let upstreamResponse = null; // () => Response

function jsonResponse(obj, status = 200, headers = {}) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'content-type': 'application/json', ...headers },
  });
}

function sseResponse(chunks, status = 200, headers = {}) {
  const encoder = new TextEncoder();
  const stream = new ReadableStream({
    start(controller) {
      for (const chunk of chunks) controller.enqueue(encoder.encode(chunk));
      controller.close();
    },
  });
  return new Response(stream, {
    status,
    headers: { 'content-type': 'text/event-stream', ...headers },
  });
}

function brokenStreamResponse() {
  const encoder = new TextEncoder();
  let pulls = 0;
  const stream = new ReadableStream({
    async pull(controller) {
      pulls += 1;
      if (pulls === 1) {
        // First read: deliver one valid SSE data chunk.
        controller.enqueue(
          encoder.encode('data: {"choices":[{"delta":{"content":"partial"}}]}\n\n'),
        );
        return;
      }
      // Subsequent reads: fail.
      throw new Error('upstream stream exploded');
    },
  });
  return new Response(stream, {
    status: 200,
    headers: { 'content-type': 'text/event-stream' },
  });
}

function freePort() {
  return new Promise((resolve, reject) => {
    const probe = net.createServer();
    probe.listen(0, '127.0.0.1', () => {
      const { port } = probe.address();
      probe.close(() => resolve(port));
    });
    probe.on('error', reject);
  });
}

// --- Harness setup (runs once, before any test) ---
const originalEnv = {
  PORT: process.env.PORT,
  OPENROUTER_MODEL: process.env.OPENROUTER_MODEL,
  OPENROUTER_FALLBACK_MODEL: process.env.OPENROUTER_FALLBACK_MODEL,
  SMARTSAVE_ALLOWED_ORIGINS: process.env.SMARTSAVE_ALLOWED_ORIGINS,
};
process.env.PORT = String(await freePort());
process.env.OPENROUTER_API_KEY = DUMMY_KEY; // dotenv will not override this
process.env.OPENROUTER_MODEL = FREE_PRIMARY;
process.env.OPENROUTER_FALLBACK_MODEL = FREE_SECONDARY;
process.env.SMARTSAVE_ALLOWED_ORIGINS = 'https://app.example.invalid';

global.fetch = async (url, options) => {
  const urlStr = String(url);
  if (urlStr.includes('openrouter.ai')) {
    upstreamCalls.push({ url: urlStr, options });
    return upstreamResponse(options);
  }
  return realFetch(url, options);
};

http.Server.prototype.listen = function (...args) {
  server = this;
  return realListen.apply(this, args);
};

console.error = () => {}; // tests intentionally trigger error-path logging

const { app } = await import('../server.js');
app.locals.verifyIdToken = async (token) => {
  if (!token.startsWith('mock-')) throw new Error('Invalid token');
  return { uid: token };
};
baseUrl = `http://127.0.0.1:${server.address().port}`;

beforeEach(() => {
  upstreamCalls = [];
  upstreamResponse = () => jsonResponse({ choices: [{ message: { content: 'ok' } }] });
});

after(() => {
  global.fetch = realFetch;
  http.Server.prototype.listen = realListen;
  console.error = realConsoleError;
  for (const [key, value] of Object.entries(originalEnv)) {
    if (value === undefined) {
      delete process.env[key];
    } else {
      process.env[key] = value;
    }
  }
  if (server) {
    server.closeAllConnections?.();
    server.close();
  }
});

async function post(body, token = 'mock-contract') {
  return realFetch(`${baseUrl}/api/chat/completions`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...(token && { authorization: `Bearer ${token}` }) },
    body: JSON.stringify(body),
  });
}

// 1. Successful non-streaming response.
test('success: non-streaming 200 passes the completion through', async () => {
  upstreamResponse = () =>
    jsonResponse(
      {
        id: 'chatcmpl-test',
        model: FREE_PRIMARY,
        choices: [{ message: { role: 'assistant', content: 'Hello from the free model.' } }],
        usage: { prompt_tokens: 5, completion_tokens: 7 },
      },
      200,
      { 'x-ratelimit-remaining': '99' },
    );

  const res = await post({ messages: [{ role: 'user', content: 'Hi' }], stream: false });
  const body = await res.json();

  assert.equal(res.status, 200);
  assert.equal(body.choices[0].message.content, 'Hello from the free model.');
  assert.equal(body.model, FREE_PRIMARY);
  assert.equal(res.headers.get('x-ratelimit-remaining'), '99');

  // The exact free model ID reached the provider; nothing else was sent.
  const upstream = JSON.parse(upstreamCalls[0].options.body);
  assert.equal(upstream.model, FREE_PRIMARY);
  assert.equal(upstream.stream, false);
  assert.equal(upstream.messages[0].role, 'user');
  assert.equal(upstreamCalls.length, 1);
});

// Client-selected free model passes through; no model switching.
test('success: client-selected free model is forwarded unchanged (no model switch)', async () => {
  upstreamResponse = () => jsonResponse({ choices: [{ message: { content: 'nemotron reply' } }] });

  const res = await post({
    model: FREE_SECONDARY,
    messages: [{ role: 'user', content: 'Hi' }],
    stream: false,
  });

  assert.equal(res.status, 200);
  const upstream = JSON.parse(upstreamCalls[0].options.body);
  assert.equal(upstream.model, FREE_SECONDARY);
  assert.equal(upstreamCalls.length, 1);
});

// 2. Successful streaming response.
test('success: streaming SSE events are forwarded and terminated with [DONE]', async () => {
  upstreamResponse = () =>
    sseResponse(
      [
        'data: {"choices":[{"delta":{"content":"Hel"}}]}\n\n',
        'data: {"choices":[{"delta":{"content":"lo"}}]}\n\n',
        'data: [DONE]\n\n',
      ],
      200,
      { 'x-ratelimit-remaining': '50' },
    );

  const res = await post({ messages: [{ role: 'user', content: 'Hi' }], stream: true });
  const text = await res.text();

  assert.equal(res.status, 200);
  assert.ok(res.headers.get('content-type')?.includes('text/event-stream'));
  assert.ok(text.includes('Hel'));
  assert.ok(text.includes('lo'));
  assert.ok(text.includes('data: [DONE]'));
  assert.equal(res.headers.get('x-ratelimit-remaining'), '50');

  const upstream = JSON.parse(upstreamCalls[0].options.body);
  assert.equal(upstream.stream, true);
  assert.equal(upstream.model, FREE_PRIMARY);
});

// 3a. Empty provider response (streaming).
test('empty response: stream with no data yields a stream_empty error event', async () => {
  upstreamResponse = () => sseResponse([]);

  const res = await post({ messages: [{ role: 'user', content: 'Hi' }], stream: true });
  const text = await res.text();

  assert.equal(res.status, 200); // headers already sent; error is signalled in-stream
  assert.ok(text.includes('stream_empty'));
  assert.ok(text.includes('data: [DONE]'));
});

// 3b. Empty provider response (non-streaming).
test('empty response: 200 with empty choices becomes 502 OPENROUTER_EMPTY_CHOICES', async () => {
  upstreamResponse = () => jsonResponse({ id: 'x', choices: [] });

  const res = await post({ messages: [{ role: 'user', content: 'Hi' }], stream: false });
  const body = await res.json();

  assert.equal(res.status, 502);
  assert.equal(body.code, 'OPENROUTER_EMPTY_CHOICES');
  assert.equal(body.isDailyQuota, false);
});

// 3c. 200 whose body is an error payload (streaming).
test('provider defect: 200 stream whose body is an error payload becomes 502', async () => {
  upstreamResponse = () => jsonResponse({ error: { message: 'upstream exploded' } }, 200);

  const res = await post({ messages: [{ role: 'user', content: 'Hi' }], stream: true });
  const body = await res.json();

  assert.equal(res.status, 502);
  assert.equal(body.code, 'OPENROUTER_HTTP_200_WITH_ERROR');
});

// 4. Interrupted / failed stream.
test('interrupted stream: mid-flight upstream failure surfaces as stream_interrupted', async () => {
  upstreamResponse = () => brokenStreamResponse();

  const res = await post({ messages: [{ role: 'user', content: 'Hi' }], stream: true });
  const text = await res.text();

  assert.equal(res.status, 200); // headers were already flushed
  assert.ok(text.includes('partial'));
  assert.ok(text.includes('stream_interrupted'));
  assert.ok(text.includes('data: [DONE]'));
});

// 5. HTTP 429 daily quota error (metadata-based detection).
test('429 daily quota: metadata limit_source is reported as OPENROUTER_DAILY_QUOTA_EXCEEDED', async () => {
  upstreamResponse = () =>
    jsonResponse(
      {
        error: { message: 'Daily limit reached' },
        metadata: { limit_source: 'openrouter_free_tier_daily' },
      },
      429,
    );

  const res = await post({ messages: [{ role: 'user', content: 'Hi' }], stream: false });
  const body = await res.json();

  assert.equal(res.status, 429);
  assert.equal(body.code, 'OPENROUTER_DAILY_QUOTA_EXCEEDED');
  assert.equal(body.isDailyQuota, true);
  assert.equal(body.retryable, false);
  assert.ok(body.error.toLowerCase().includes('daily'));
  assert.ok(!body.error.includes(DUMMY_KEY));
});

// 5b. HTTP 429 daily quota (header-based detection).
test('429 daily quota: zero remaining + reset >1h is detected as daily quota', async () => {
  upstreamResponse = () =>
    jsonResponse({ error: { message: 'Rate limited' } }, 429, {
      'x-ratelimit-remaining': '0',
      'x-ratelimit-limit': '100',
      'x-ratelimit-reset': String(Date.now() + 7_200_000),
    });

  const res = await post({ messages: [{ role: 'user', content: 'Hi' }], stream: false });
  const body = await res.json();

  assert.equal(res.status, 429);
  assert.equal(body.code, 'OPENROUTER_DAILY_QUOTA_EXCEEDED');
  assert.equal(body.isDailyQuota, true);
});

// 6. HTTP 429 temporary rate-limit error.
test('429 temporary: plain rate limit without daily-quota metadata stays retryable', async () => {
  upstreamResponse = () => jsonResponse({ error: { message: 'Too many requests' } }, 429);

  const res = await post({ messages: [{ role: 'user', content: 'Hi' }], stream: false });
  const body = await res.json();

  assert.equal(res.status, 429);
  assert.equal(body.code, 'OPENROUTER_HTTP_429');
  assert.equal(body.isDailyQuota, false);
  assert.equal(body.retryable, true);
});

// 7. HTTP 401 authentication error.
test('401: authentication error is forwarded with its code', async () => {
  upstreamResponse = () => jsonResponse({ error: { message: 'Invalid API key' } }, 401);

  const res = await post({ messages: [{ role: 'user', content: 'Hi' }], stream: false });
  const body = await res.json();

  assert.equal(res.status, 401);
  assert.equal(body.code, 'OPENROUTER_HTTP_401');
  assert.equal(body.isDailyQuota, false);
});

test('402: preserves an upstream credit error', async () => {
  upstreamResponse = () => jsonResponse({ error: { message: 'Insufficient credits' } }, 402);
  const response = await post({ messages: [{ role: 'user', content: 'Hi' }], stream: true });
  assert.equal(response.status, 402);
  assert.equal((await response.json()).code, 'OPENROUTER_HTTP_402');
});

test('SSE EOF does not fabricate upstream completion', async () => {
  upstreamResponse = () => sseResponse(['data: {"choices":[{"delta":{"content":"partial"}}]}\n\n']);
  const response = await post({ messages: [{ role: 'user', content: 'Hi' }], stream: true });
  const text = await response.text();
  assert.match(text, /partial/);
  assert.doesNotMatch(text, /\[DONE\]/);
});

// 8. HTTP 500 provider/server error + key sanitization.
test('500: provider error is forwarded and any API-key-shaped text is redacted', async () => {
  upstreamResponse = () =>
    jsonResponse({ error: { message: `boom ${FAKE_LEAKED_KEY} boom` } }, 500);

  const res = await post({ messages: [{ role: 'user', content: 'Hi' }], stream: false });
  const bodyText = await res.text();
  const body = JSON.parse(bodyText);

  assert.equal(res.status, 500);
  assert.equal(body.code, 'OPENROUTER_HTTP_500');
  assert.equal(body.retryable, true);
  assert.ok(!bodyText.includes(FAKE_LEAKED_KEY), 'leaked key must not appear');
  assert.ok(bodyText.includes('[REDACTED_API_KEY]'));
});

// 10. Rejection of non-free model IDs.
test('non-free model: paid model IDs are rejected and upstream is never called', async () => {
  const res = await post({
    model: 'openai/gpt-4o',
    messages: [{ role: 'user', content: 'Hi' }],
    stream: false,
  });
  const body = await res.json();

  assert.equal(res.status, 400);
  assert.equal(body.code, 'NON_FREE_MODEL_REJECTED');
  assert.equal(upstreamCalls.length, 0); // no request left this machine
  assert.equal(body.model, FREE_PRIMARY); // response still names the free default
});

// Extra: missing API key (implemented in server.js).
test('missing key: 503 OPENROUTER_KEY_MISSING when no API key is configured', async () => {
  const saved = process.env.OPENROUTER_API_KEY;
  delete process.env.OPENROUTER_API_KEY;
  try {
    assert.equal((await realFetch(`${baseUrl}/health`)).status, 200);
    const res = await post({ messages: [{ role: 'user', content: 'Hi' }], stream: false });
    const body = await res.json();

    assert.equal(res.status, 503);
    assert.equal(body.code, 'OPENROUTER_KEY_MISSING');
    assert.equal(upstreamCalls.length, 0);
  } finally {
    process.env.OPENROUTER_API_KEY = saved;
  }
});

// Extra: free-tier configuration endpoints.
test('config: /health and /api/models report free-tier-only configuration', async () => {
  const health = await realFetch(`${baseUrl}/health`);
  const healthBody = await health.json();
  assert.equal(health.status, 200);
  assert.equal(healthBody.status, 'ok');
  assert.ok(healthBody.model.endsWith(':free'));

  const models = await realFetch(`${baseUrl}/api/models`);
  const modelsBody = await models.json();
  assert.equal(modelsBody.freeTierOnly, true);
  assert.ok(modelsBody.defaultModel.endsWith(':free'));
  assert.ok(modelsBody.fallbackModel.endsWith(':free'));
});

test('security: denies missing and invalid tokens before contacting OpenRouter', async () => {
  const body = { messages: [{ role: 'user', content: 'Hi' }] };
  assert.equal((await post(body, null)).status, 401);
  assert.equal((await post(body, 'invalid')).status, 401);
  assert.equal(upstreamCalls.length, 0);
});

test('security: validates payload types and rejects oversized bodies', async () => {
  assert.equal((await post({ messages: ['not a message'] })).status, 400);
  assert.equal((await post({ messages: [{ role: 'user', content: 'a'.repeat(1024 * 1024) }] })).status, 413);
  assert.equal(upstreamCalls.length, 0);
});

test('security: limits authenticated requests per verified UID', async () => {
  const body = { messages: [{ role: 'user', content: 'Hi' }] };
  for (let index = 0; index < 30; index++) {
    assert.equal((await post(body, 'mock-rate')).status, 200);
  }
  const response = await post(body, 'mock-rate');
  assert.equal(response.status, 429);
  assert.ok(response.headers.get('retry-after'));
  assert.equal((await post(body, 'mock-another-account')).status, 200);
});

test('web preflight permits the configured origin and bearer header', async () => {
  const origin = 'https://app.example.invalid';
  const response = await realFetch(`${baseUrl}/api/chat/completions`, {
    method: 'OPTIONS',
    headers: {
      Origin: origin,
      'Access-Control-Request-Method': 'POST',
      'Access-Control-Request-Headers': 'authorization,content-type',
    },
  });
  assert.equal(response.status, 204);
  assert.equal(response.headers.get('access-control-allow-origin'), origin);
  assert.match(response.headers.get('access-control-allow-headers'), /authorization/);
  assert.equal(upstreamCalls.length, 0);
});

test('security: health stays public and arbitrary browser origins receive no CORS grant', async () => {
  const response = await realFetch(`${baseUrl}/health`, { headers: { Origin: 'https://other.example' } });
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('access-control-allow-origin'), null);
  assert.equal(response.headers.get('x-content-type-options'), 'nosniff');
  assert.equal(response.headers.get('x-powered-by'), null);
});

test('deletion requires recent authentication, scopes retries to the verified UID, and reports partial failure', async () => {
  const url = `${baseUrl}/api/account/delete-data`;
  const request = (token) => realFetch(url, {
    method: 'POST',
    headers: token ? { authorization: `Bearer ${token}` } : {},
    body: JSON.stringify({ uid: 'ignored-other-user' }),
  });
  const deleted = [];
  const now = Math.floor(Date.now() / 1000);
  app.locals.verifyDeletionToken = async (token) => {
    if (token === 'invalid') throw new Error('invalid');
    return { uid: 'verified-owner', auth_time: token === 'old' ? now - 400 : now };
  };
  app.locals.deleteCloudRecords = async (uid) => {
    deleted.push(uid);
    if (deleted.length === 1) throw new Error('incomplete');
  };
  try {
    assert.equal((await request()).status, 401);
    assert.equal((await request('invalid')).status, 401);
    assert.equal((await request('old')).status, 403);
    assert.deepEqual(deleted, []);
    assert.equal((await request('recent')).status, 503);
    assert.equal((await request('recent')).status, 204);
    assert.deepEqual(deleted, ['verified-owner', 'verified-owner']);
  } finally {
    delete app.locals.verifyDeletionToken;
    delete app.locals.deleteCloudRecords;
  }
});

test('upstream deadline aborts a request without returning provider details', async () => {
  const originalTimeout = app.locals.upstreamTimeoutMs;
  app.locals.upstreamTimeoutMs = 30;
  upstreamResponse = ({ signal }) => new Promise((resolve, reject) => {
    signal.addEventListener('abort', () => reject(signal.reason), { once: true });
  });
  try {
    const response = await post({ messages: [{ role: 'user', content: 'synthetic prompt' }] });
    assert.equal(response.status, 504);
    const body = await response.json();
    assert.equal(body.code, 'UPSTREAM_TIMEOUT');
    assert.equal(body.retryable, true);
  } finally {
    app.locals.upstreamTimeoutMs = originalTimeout;
  }
});

test('transport failure does not log or return the prompt or credential', async () => {
  const prompt = 'private synthetic prompt fixture';
  const messages = [];
  const previousLogger = console.error;
  console.error = (...args) => messages.push(args.join(' '));
  upstreamResponse = () => { throw new Error(`${prompt} ${DUMMY_KEY}`); };
  try {
    const response = await post({ messages: [{ role: 'user', content: prompt }] });
    assert.equal(response.status, 500);
    const output = await response.text();
    assert.ok(messages.length > 0);
    for (const text of [output, ...messages]) {
      assert.ok(!text.includes(prompt));
      assert.ok(!text.includes(DUMMY_KEY));
    }
  } finally {
    console.error = previousLogger;
  }
});

test('closing the client connection aborts the upstream request', async () => {
  const client = new AbortController();
  let markStarted;
  let markAborted;
  const started = new Promise((resolve) => { markStarted = resolve; });
  const aborted = new Promise((resolve) => { markAborted = resolve; });
  upstreamResponse = ({ signal }) => new Promise((_, reject) => {
    signal.addEventListener('abort', () => {
      markAborted();
      reject(signal.reason);
    }, { once: true });
    markStarted();
  });
  const request = realFetch(`${baseUrl}/api/chat/completions`, {
    method: 'POST', signal: client.signal,
    headers: { 'content-type': 'application/json', authorization: 'Bearer mock-disconnect' },
    body: JSON.stringify({ messages: [{ role: 'user', content: 'fixture' }] }),
  });
  const rejected = assert.rejects(request, { name: 'AbortError' });
  await started;
  client.abort();
  await Promise.all([rejected, aborted]);
});
