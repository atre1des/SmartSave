// backend/server.js
import express from 'express';
import cors from 'cors';
import 'dotenv/config';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

export const app = express();
const firebaseProjectId = process.env.FIREBASE_PROJECT_ID;
const firebaseApp = firebaseProjectId
  ? initializeApp({ projectId: firebaseProjectId })
  : null;
app.locals.verifyIdToken = firebaseApp
  ? (token) => getAuth(firebaseApp).verifyIdToken(token)
  : null;
if (firebaseApp && process.env.SMARTSAVE_ENABLE_ACCOUNT_DELETION === 'true') {
  app.locals.verifyDeletionToken = (token) => getAuth(firebaseApp).verifyIdToken(token, true);
  app.locals.deleteCloudRecords = async (uid) => {
    const firestore = getFirestore(firebaseApp);
    // The rules deny client access once this lock exists. Keep the lock through
    // retries and after Auth deletion to prevent outstanding uploads.
    await firestore.collection('accountDeletionLocks').doc(uid).set({ locked: true });
    await firestore.recursiveDelete(firestore.collection('users').doc(uid));
  };
}
const PORT = process.env.PORT || 3001;
app.locals.upstreamTimeoutMs = 120_000;

// --- Model configuration (free-tier only, no paid fallbacks) ---
// Primary free model: ERNIE 5.5 Flash Preview (free)
// Fallback free model: NVIDIA Nemotron 3 Ultra 550B (free)
// Both verified $0 input / $0 output pricing on OpenRouter.
const DEFAULT_MODEL =
  process.env.OPENROUTER_MODEL || 'baidu/ernie-5.5-flash-preview:free';
const FALLBACK_MODEL =
  process.env.OPENROUTER_FALLBACK_MODEL ||
  'nvidia/nemotron-3-ultra-550b-a55b:free';

// Verify the configured models are free-tier variants.
// If a non-free model is configured, refuse to start.
const FREE_MODEL_PATTERNS = [':free'];
function isFreeModel(modelId) {
  if (!modelId) return false;
  return FREE_MODEL_PATTERNS.some((p) => modelId.endsWith(p));
}

if (!isFreeModel(DEFAULT_MODEL)) {
  console.error(
    `[SmartSave] Refusing to start: OPENROUTER_MODEL is not a free-tier model. Only ":free" models are allowed.`,
  );
  process.exit(1);
}
if (FALLBACK_MODEL && !isFreeModel(FALLBACK_MODEL)) {
  console.warn(
    `[SmartSave] Warning: OPENROUTER_FALLBACK_MODEL is not a free-tier model. It will NOT be used as an automatic fallback.`,
  );
}

const allowedOrigins = new Set(
  (process.env.SMARTSAVE_ALLOWED_ORIGINS ?? '').split(',').map((value) => value.trim()).filter(Boolean),
);
app.disable('x-powered-by');
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  next();
});
app.use(cors({ origin: (origin, callback) => callback(null, allowedOrigins.has(origin)) }));

const rateWindow = 60_000;
function rateLimit(keyFor, maximum) {
  const buckets = new Map();
  return (req, res, next) => {
    const now = Date.now();
    for (const [key, bucket] of buckets) {
      if (bucket.until <= now) buckets.delete(key);
    }
    const key = keyFor(req);
    let bucket = buckets.get(key);
    if (!bucket && buckets.size < 4096) {
      bucket = { count: 0, until: now + rateWindow };
      buckets.set(key, bucket);
    }
    if (!bucket || bucket.count >= maximum) {
      res.setHeader('Retry-After', String(Math.ceil(((bucket?.until ?? now + rateWindow) - now) / 1000)));
      return rejectRequest(res, 429, 'RATE_LIMITED', 'Too many requests. Please try again shortly.');
    }
    bucket.count++;
    next();
  };
}

function rejectRequest(res, status, code, message) {
  return res.status(status).json(buildErrorResponse({
    status, code, message, retryable: status === 429 || status >= 500,
  }));
}

async function authenticate(req, res, next) {
  const bearer = /^Bearer ([^\s]+)$/i.exec(req.get('authorization') ?? '');
  if (!bearer || bearer[1].length > 8192) {
    return rejectRequest(res, 401, 'AUTH_REQUIRED', 'A Firebase ID token is required.');
  }
  const verify = req.app.locals.verifyIdToken;
  if (!verify) {
    return rejectRequest(res, 503, 'AUTH_UNAVAILABLE', 'Authentication is unavailable.');
  }
  try {
    const claims = await verify(bearer[1]);
    if (typeof claims.uid !== 'string' || !claims.uid) throw new Error('Missing UID');
    req.authUid = claims.uid;
  } catch {
    return rejectRequest(res, 401, 'AUTH_INVALID', 'The Firebase ID token could not be verified.');
  }
  next();
}

app.post('/api/account/delete-data', rateLimit((req) => req.ip, 12), async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  const token = /^Bearer ([^\s]+)$/i.exec(req.get('authorization') ?? '')?.[1];
  if (!token || token.length > 8192) {
    return rejectRequest(res, 401, 'AUTH_REQUIRED', 'A Firebase ID token is required.');
  }
  const { verifyDeletionToken, deleteCloudRecords } = req.app.locals;
  if (!verifyDeletionToken || !deleteCloudRecords) {
    return rejectRequest(res, 503, 'DELETION_UNAVAILABLE', 'Account deletion is unavailable.');
  }
  let claims;
  try {
    claims = await verifyDeletionToken(token);
  } catch {
    return rejectRequest(res, 401, 'AUTH_INVALID', 'The Firebase ID token could not be verified.');
  }
  const now = Math.floor(Date.now() / 1000);
  if (typeof claims.uid !== 'string' || !claims.uid || /[/]/.test(claims.uid) ||
      claims.uid === '.' || claims.uid === '..' ||
      !Number.isInteger(claims.auth_time) || claims.auth_time > now ||
      now - claims.auth_time >= 300) {
    return rejectRequest(res, 403, 'RECENT_SIGN_IN_REQUIRED', 'Sign in again to delete account data.');
  }
  try {
    await deleteCloudRecords(claims.uid);
    return res.sendStatus(204);
  } catch {
    return rejectRequest(res, 503, 'CLOUD_CLEANUP_INCOMPLETE',
      'Cloud cleanup could not be confirmed. Sign in and retry deletion.');
  }
});

function validateCompletion(req, res, next) {
  const { model, messages, temperature, max_tokens, stream } = req.body ?? {};
  const validMessages = Array.isArray(messages) && messages.length > 0 &&
    messages.every((message) => message &&
      ['system', 'user', 'assistant'].includes(message.role) &&
      typeof message.content === 'string');
  if (!req.is('application/json') || !validMessages ||
      (model != null && typeof model !== 'string') ||
      (temperature != null && (!Number.isFinite(temperature) || temperature < 0 || temperature > 2)) ||
      (max_tokens != null && (!Number.isSafeInteger(max_tokens) || max_tokens <= 0)) ||
      (stream != null && typeof stream !== 'boolean')) {
    return rejectRequest(res, 400, 'INVALID_REQUEST', 'Invalid chat completion request.');
  }
  next();
}

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'SmartSave AI Proxy (OpenRouter)',
    model: DEFAULT_MODEL,
    fallbackModel: FALLBACK_MODEL,
  });
});

// Helper: extract rate limit headers from upstream response
function extractRateLimitHeaders(upstreamResponse) {
  const headers = {};
  const rateLimitHeaders = [
    'x-ratelimit-limit',
    'x-ratelimit-remaining',
    'x-ratelimit-reset',
    'retry-after',
    'x-ratelimit-limit-requests',
    'x-ratelimit-remaining-requests',
    'x-ratelimit-limit-tokens',
    'x-ratelimit-remaining-tokens',
  ];
  for (const header of rateLimitHeaders) {
    const value = upstreamResponse.headers.get(header);
    if (value) headers[header] = value;
  }
  return headers;
}

// Helper: determine if error is daily quota exhaustion
function isDailyQuotaExhausted(upstreamResponse, errorBody) {
  const limitSource = errorBody?.metadata?.limit_source;
  if (limitSource === 'openrouter_free_tier_daily') return true;

  // Also check rate limit headers
  const remaining = upstreamResponse.headers.get('x-ratelimit-remaining');
  const limit = upstreamResponse.headers.get('x-ratelimit-limit');
  if (remaining !== null && limit !== null) {
    const rem = parseInt(remaining, 10);
    const lim = parseInt(limit, 10);
    if (!isNaN(rem) && !isNaN(lim) && rem === 0 && lim > 0) {
      const reset = upstreamResponse.headers.get('x-ratelimit-reset');
      if (reset) {
        const resetMs = parseInt(reset, 10);
        if (!isNaN(resetMs)) {
          const resetTime = new Date(resetMs);
          const now = new Date();
          // If reset is more than 1 hour away, likely daily quota
          if (resetTime.getTime() - now.getTime() > 3600000) {
            return true;
          }
        }
      }
    }
  }
  return false;
}

// Helper: sanitize error response (remove API keys, etc.)
function sanitizeErrorResponse(errorText) {
  return errorText
    .replace(/sk-or-v1-[a-zA-Z0-9-_]{32,}/g, '[REDACTED_API_KEY]')
    .replace(/gsk_[a-zA-Z0-9]{32,}/g, '[REDACTED_API_KEY]');
}

// Helper: parse a streamed error body into a structured object
function parseStreamError(errorText, status) {
  let errorBody = null;
  try {
    errorBody = JSON.parse(errorText);
  } catch (e) {
    // Not JSON, use text as-is
  }
  const message =
    errorBody?.error?.message ||
    errorBody?.message ||
    errorBody?.error ||
    errorText ||
    'Unknown error';
  return {
    status,
    message: sanitizeErrorResponse(String(message)),
    body: errorBody,
  };
}

// Helper: build a normalized error response object
function buildErrorResponse({
  status,
  message,
  code,
  isDailyQuota,
  retryable,
  rateLimit,
  upstreamStatus,
}) {
  return {
    error: message,
    code,
    isDailyQuota: !!isDailyQuota,
    retryable: !!retryable,
    rateLimit,
    upstreamStatus,
    model: DEFAULT_MODEL,
  };
}

// Chat completions proxy (OpenRouter OpenAI-compatible API)
app.post('/api/chat/completions',
  rateLimit((req) => req.ip, 120),
  authenticate,
  rateLimit((req) => req.authUid, 30),
  express.json({ limit: '1mb' }),
  validateCompletion,
  async (req, res) => {
  let deadline;
  try {
    const { model, messages, temperature, max_tokens, stream } = req.body;

    const openRouterApiKey = process.env.OPENROUTER_API_KEY;
    if (
      !openRouterApiKey ||
      openRouterApiKey.trim() === '' ||
      openRouterApiKey === 'paste_your_openrouter_key_here'
    ) {
      return res.status(503).json(
        buildErrorResponse({
          status: 503,
          message:
            'OpenRouter API key not configured. Set OPENROUTER_API_KEY in backend/.env.',
          code: 'OPENROUTER_KEY_MISSING',
          isDailyQuota: false,
          retryable: false,
        }),
      );
    }

    // Determine the model to use.
    // The client may send a specific model; if not, use the configured default.
    const selectedModel = model || DEFAULT_MODEL;

    // Enforce free-tier-only: reject any non-free model selection.
    if (!isFreeModel(selectedModel)) {
      return res.status(400).json(
        buildErrorResponse({
          status: 400,
          message: `Model "${selectedModel}" is not a free-tier model. Only ":free" models are allowed on SmartSave.`,
          code: 'NON_FREE_MODEL_REJECTED',
          isDailyQuota: false,
          retryable: false,
        }),
      );
    }

    const upstream = new AbortController();
    res.once('close', () => {
      if (!res.writableEnded) upstream.abort();
    });
    deadline = setTimeout(
      () => upstream.abort(new DOMException('Upstream timeout', 'TimeoutError')),
      req.app.locals.upstreamTimeoutMs,
    );
    deadline.unref();
    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      signal: upstream.signal,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${openRouterApiKey}`,
        'HTTP-Referer': 'https://github.com/smartsave',
        'X-Title': 'SmartSave',
      },
      body: JSON.stringify({
        model: selectedModel,
        messages,
        temperature: temperature ?? 0.7,
        max_tokens: max_tokens ?? 2000,
        stream: stream ?? false,
      }),
    });

    const rateLimitHeaders = extractRateLimitHeaders(response);

    if (!response.ok) {
      let errorText = '';
      try {
        errorText = await response.text();
      } catch (e) {
        errorText = 'Unable to read error response body';
      }
      let errorBody = null;
      try {
        errorBody = JSON.parse(errorText);
      } catch (e) {
        // Not JSON
      }

      const dailyQuotaExhausted = isDailyQuotaExhausted(response, errorBody);
      const parsed = parseStreamError(errorText, response.status);

      console.error(
        `OpenRouter API error: ${response.status} (dailyQuota=${dailyQuotaExhausted})`,
      );

      return res.status(response.status).json(
        buildErrorResponse({
          status: response.status,
          message: dailyQuotaExhausted
            ? 'OpenRouter free-tier daily quota exhausted. Please try again later (resets at midnight UTC).'
            : parsed.message,
          code: dailyQuotaExhausted
            ? 'OPENROUTER_DAILY_QUOTA_EXCEEDED'
            : `OPENROUTER_HTTP_${response.status}`,
          isDailyQuota: dailyQuotaExhausted,
          retryable: !dailyQuotaExhausted && (response.status === 429 || response.status >= 500),
          rateLimit:
            Object.keys(rateLimitHeaders).length > 0 ? rateLimitHeaders : undefined,
          upstreamStatus: response.status,
        }),
      );
    }

    // --- Successful upstream response ---
    if (stream) {
      // Check Content-Type to ensure it's actually a stream
      const contentType = response.headers.get('content-type') || '';
      if (!contentType.includes('text/event-stream')) {
        // Upstream returned non-streaming (e.g., an error in JSON form with 200).
        const text = await response.text();
        let parsed = null;
        try {
          parsed = JSON.parse(text);
        } catch (e) {
          // not JSON
        }
        if (parsed?.error) {
          console.error(
            'OpenRouter returned 200 with an error payload',
          );
          return res.status(502).json(
            buildErrorResponse({
              status: 502,
              message:
                parsed.error.message ||
                parsed.error ||
                'Upstream returned an error payload in a 200 response.',
              code: 'OPENROUTER_HTTP_200_WITH_ERROR',
              isDailyQuota: false,
              retryable: true,
              upstreamStatus: 200,
            }),
          );
        }
        // No error, just not a stream - return as normal JSON
        for (const [key, value] of Object.entries(rateLimitHeaders)) {
          res.setHeader(key, value);
        }
        return res.json(parsed || {});
      }

      // Proxy the SSE stream
      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');
      res.setHeader('Connection', 'keep-alive');
      res.setHeader('X-Accel-Buffering', 'no');
      for (const [key, value] of Object.entries(rateLimitHeaders)) {
        res.setHeader(key, value);
      }
      res.flushHeaders();

      try {
        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let receivedAny = false;

        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          receivedAny = true;
          const chunk = decoder.decode(value, { stream: true });
          // Forward the raw SSE chunk (already formatted as "data: {...}\n\n")
          res.write(chunk);
        }

        // If stream ended without any data, send a synthetic error event
        if (!receivedAny) {
          console.error('OpenRouter stream ended without sending any data');
          res.write(
            `data: ${JSON.stringify({
              error: {
                message: 'Upstream stream ended without any data.',
                type: 'stream_empty',
              },
            })}\n\n`,
          );
        }

        // Always signal end
        res.write('data: [DONE]\n\n');
        res.end();
      } catch (streamErr) {
        console.error('Upstream stream was interrupted');
        if (!res.headersSent) {
          return res.status(502).json(
            buildErrorResponse({
              status: 502,
              message: 'Upstream stream interrupted: ' + streamErr.message,
              code: 'STREAM_INTERRUPTED',
              isDailyQuota: false,
              retryable: true,
            }),
          );
        }
        // Headers already sent - send error event then end
        try {
          res.write(
            `data: ${JSON.stringify({
              error: {
                message: 'Stream interrupted: ' + streamErr.message,
                type: 'stream_interrupted',
              },
            })}\n\n`,
          );
          res.write('data: [DONE]\n\n');
          res.end();
        } catch (e) {
          // Response already closed
        }
      }
    } else {
      // Non-streaming response
      const data = await response.json();

      // Check for an error payload in an otherwise 200 response
      if (data?.error) {
        console.error(
          'OpenRouter returned 200 with an error payload',
        );
        return res.status(502).json(
          buildErrorResponse({
            status: 502,
            message:
              (typeof data.error === 'string'
                ? data.error
                : data.error?.message) || 'Upstream error in 200 response.',
            code: 'OPENROUTER_HTTP_200_WITH_ERROR',
            isDailyQuota: false,
            retryable: true,
            upstreamStatus: 200,
          }),
        );
      }

      // Check for empty choices
      const choices = data?.choices;
      if (!choices || !Array.isArray(choices) || choices.length === 0) {
        console.error('OpenRouter returned 200 but choices array is empty');
        return res.status(502).json(
          buildErrorResponse({
            status: 502,
            message: 'Upstream returned 200 but no completion choices were provided.',
            code: 'OPENROUTER_EMPTY_CHOICES',
            isDailyQuota: false,
            retryable: true,
            upstreamStatus: 200,
          }),
        );
      }

      for (const [key, value] of Object.entries(rateLimitHeaders)) {
        res.setHeader(key, value);
      }
      res.json(data);
    }
  } catch (error) {
    if (res.destroyed) return;
    if (error?.name === 'TimeoutError') {
      return rejectRequest(res, 504, 'UPSTREAM_TIMEOUT', 'The AI provider timed out.');
    }
    console.error('OpenRouter proxy request failed');
    res.status(500).json(
      buildErrorResponse({
        status: 500,
        message: 'Proxy server error.',
        code: 'PROXY_ERROR',
        isDailyQuota: false,
        retryable: true,
      }),
    );
  } finally {
    clearTimeout(deadline);
  }
});

app.use((error, req, res, next) => {
  if (res.headersSent) return next(error);
  if (error.type === 'entity.too.large') {
    return rejectRequest(res, 413, 'REQUEST_TOO_LARGE', 'Request body exceeds the size limit.');
  }
  return rejectRequest(res, 400, 'INVALID_REQUEST', 'Invalid request body.');
});

// List configured models (for debugging/UI)
app.get('/api/models', (req, res) => {
  res.json({
    defaultModel: DEFAULT_MODEL,
    fallbackModel: FALLBACK_MODEL,
    freeTierOnly: true,
  });
});

app.listen(PORT, () => {
  console.log(`SmartSave AI Proxy (OpenRouter) running on http://localhost:${PORT}`);
  console.log(`  Primary model: ${DEFAULT_MODEL}`);
  console.log(`  Fallback model: ${FALLBACK_MODEL}`);
});