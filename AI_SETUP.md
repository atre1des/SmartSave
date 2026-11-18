# SmartSave AI Assistant — OpenRouter API Setup Guide

This guide explains how to enable the real AI assistant (powered by OpenRouter's free API tier) in SmartSave. Without an API key, the app runs in **offline mode** using local rule-based responses.

---

## Quick Overview

| Mode | Description |
|------|-------------|
| **Offline (default)** | Uses local rule-based responses. Shows "Running in offline mode (no API key)." |
| **Online (with API key)** | Connects to OpenRouter API for real AI responses. Shows "AI Connected". |

---

## Prerequisites

1. **OpenRouter Account** — Sign up at [openrouter.ai](https://openrouter.ai) (no credit card required for free tier)
2. **API Key** — Generate an API key from your OpenRouter dashboard
3. **Windows PowerShell** — This guide uses PowerShell commands
4. **Flutter SDK** — Already installed in your project
5. **Node.js** (v18+) — For the backend proxy server

---

## Step 1: Get Your OpenRouter API Key

1. Go to [https://openrouter.ai/keys](https://openrouter.ai/keys)
2. Click **"Create API Key"**
3. Name it (e.g., `SmartSave Dev`)
4. Copy the key (starts with `sk-or-v1-...`)
5. **Save it securely** — you won't see it again

---

## Step 2: Configure the API Key

### Option A: Set in Backend .env (Recommended)

The API key is stored in the backend's `.env` file — never in Flutter code.

1. Open `backend/.env` and set:
```env
OPENROUTER_API_KEY=sk-or-v1-YOUR_ACTUAL_KEY_HERE
PORT=3001

# Model configuration (FREE TIER ONLY - the backend refuses non-free models)
OPENROUTER_MODEL=baidu/ernie-5.5-flash-preview:free
OPENROUTER_FALLBACK_MODEL=nvidia/nemotron-3-ultra-550b-a55b:free
```

> **Note**: After editing `.env`, restart the backend server for changes to take effect.

---

## Step 3: Start the Backend Proxy Server

The app uses a local backend proxy (Node.js) to connect to OpenRouter. This keeps your API key secure and handles CORS.

### Prerequisites for Backend

- **Node.js** (v18+) — Download from [nodejs.org](https://nodejs.org)

### Setup Backend

1. Navigate to the backend folder:
```powershell
# From project root
cd backend
```

2. Install dependencies (only needed once):
```powershell
npm install
```

3. Ensure `backend/.env` has your OpenRouter key:
```env
OPENROUTER_API_KEY=sk-or-v1-YOUR_ACTUAL_KEY_HERE
PORT=3001

# Model configuration (FREE TIER ONLY - the backend refuses non-free models)
OPENROUTER_MODEL=baidu/ernie-5.5-flash-preview:free
OPENROUTER_FALLBACK_MODEL=nvidia/nemotron-3-ultra-550b-a55b:free
```

4. Start the backend:
```powershell
npm start
```

You should see:
```
SmartSave AI Proxy (OpenRouter) running on http://localhost:3001
```

---

## Step 4: Run the Flutter App

### For Android Emulator
```powershell
# In a NEW PowerShell window (so backend keeps running)
cd C:\Users\damir\OneDrive\2026-2027\Fall 2026\Capstone Project\smartsave_v5
flutter run
```

### For Windows Desktop
```powershell
flutter run -d windows
```

### For Web
```powershell
flutter run -d chrome --web-renderer html
```

---

## Step 5: Verify AI is Connected

1. Open the app
2. Navigate to the **AI tab** (center tab with sparkle icon ✨)
3. Look at the top-right status badge:
   - ✅ **Green "AI Connected"** = Successfully connected to OpenRouter via backend
   - ⚠️ **Yellow "Offline Mode"** = API key not configured or backend not running

4. Try asking a question:
   - "Explain how a bank deposit works in Kazakhstan"
   - "Compare a 3-year deposit vs investing in shares"
   - "Help me reach my savings goal of 500,000 KZT"

---

## Troubleshooting

### "Offline Mode" still showing after setup

**Check 1: Backend running?**
```powershell
# Test backend health
curl http://localhost:3001/health
# Should return: {"status":"ok","service":"SmartSave AI Proxy (OpenRouter)","model":"baidu/ernie-5.5-flash-preview:free","fallbackModel":"nvidia/nemotron-3-ultra-550b-a55b:free"}
```

**Check 2: API Key in backend/.env?**
```powershell
type backend\.env
# Should show OPENROUTER_API_KEY=sk-or-v1-...
```

**Check 3: Backend logs**
Look at the PowerShell window running `npm start` for error messages.

**Check 4: Restart everything**
1. Stop Flutter app (Ctrl+C)
2. Stop backend (Ctrl+C in backend window)
3. Restart backend: `cd backend && npm start`
4. Restart Flutter: `flutter run`

### "Cannot connect to backend" error

The app tries to connect to:
- **Android Emulator**: `http://10.0.2.2:3001` (special IP for host machine)
- **iOS Simulator / Desktop / Web**: `http://localhost:3001`

If you're on a physical device, change the backend URL in `lib/ai/openrouter_provider.dart`:
```dart
// Line ~52: Change to your computer's LAN IP
static String _getDefaultBackendUrl() {
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:3001'; // Emulator
  }
  return 'http://YOUR_LAN_IP:3001'; // Physical device
}
```

### Backend fails to start (port in use)

```powershell
# Find process using port 3001
netstat -ano | findstr :3001

# Kill it (replace PID)
taskkill /PID <PID> /F

# Or use different port in backend/.env
PORT=3002
```
Then update `lib/ai/openrouter_provider.dart` to match the new port.

### API Key Invalid / Rate Limited

1. Verify key at [openrouter.ai/keys](https://openrouter.ai/keys)
2. Check usage/limits on OpenRouter dashboard
3. Free tier has a daily request quota. If it is exhausted, the app shows a
   "daily request limit" banner and never auto-retries — wait and retry
   manually after the quota resets (midnight UTC).

---

## Model Configuration

The app uses **`baidu/ernie-5.5-flash-preview:free`** (Baidu ERNIE 5.5 Flash Preview) by default — verified $0 input / $0 output on OpenRouter's free tier.

The secondary free alternative is **`nvidia/nemotron-3-ultra-550b-a55b:free`** (NVIDIA Nemotron 3 Ultra 550B, also $0/$0). It is **never** selected automatically; to use it, edit `OPENROUTER_MODEL` in `backend/.env` manually.

To change the model, edit `backend/.env`:

```env
# backend/.env
OPENROUTER_MODEL=baidu/ernie-5.5-flash-preview:free
OPENROUTER_FALLBACK_MODEL=nvidia/nemotron-3-ultra-550b-a55b:free
```

Or set the Flutter-side default in `lib/ai/config.dart`:

```dart
// lib/ai/config.dart
static const String defaultModel = 'baidu/ernie-5.5-flash-preview:free';
// Free alternative (never used automatically):
static const String fallbackModel = 'nvidia/nemotron-3-ultra-550b-a55b:free';
```

SmartSave is free-tier only by design:
- The backend refuses to start if `OPENROUTER_MODEL` is not a `:free` model.
- The backend rejects any client-sent non-free model with HTTP 400.
- The app never automatically switches to a paid model, and no paid fallbacks exist.

No credit card required for the free tier.

---

## Security Notes

✅ **DO:**
- Store API key in backend/.env (not in Flutter code)
- Keep backend on localhost only
- Use environment variables for development

❌ **DON'T:**
- Commit API keys to git
- Put API keys directly in Flutter/Dart code
- Expose backend to public internet without auth

---

## Quick Test Commands

```powershell
# 1. Test backend health
curl http://localhost:3001/health

# 2. Test chat completion (non-streaming)
curl -X POST http://localhost:3001/api/chat/completions `
  -H "Content-Type: application/json" `
  -d '{"model":"baidu/ernie-5.5-flash-preview:free","messages":[{"role":"user","content":"Hello"}],"stream":false}'

# 3. Test streaming
curl -X POST http://localhost:3001/api/chat/completions `
  -H "Content-Type: application/json" `
  -d '{"model":"baidu/ernie-5.5-flash-preview:free","messages":[{"role":"user","content":"Count to 5"}],"stream":true}'
```

---

## Summary Checklist

- [ ] OpenRouter account created at openrouter.ai
- [ ] API key generated and saved in backend/.env as OPENROUTER_API_KEY
- [ ] Backend folder has package.json, .env, server.js
- [ ] `npm install` completed in backend
- [ ] Backend running on port 3001 (`npm start`)
- [ ] Flutter app running (`flutter run`)
- [ ] App shows "AI Connected" (green badge)
- [ ] Test question returns AI response

---

## File Reference

| File | Purpose |
|------|---------|
| `lib/ai/config.dart` | API config, model selection, key detection |
| `lib/ai/openrouter_provider.dart` | HTTP client for backend proxy (contains OpenRouterProvider) |
| `lib/ai/models.dart` | AIMessage data model with JSON serialization |
| `lib/features/advice/ai_assistant_screen.dart` | AI chat UI with conversation persistence |
| `backend/server.js` | Express proxy server (proxies to OpenRouter) |
| `backend/.env` | API key and port configuration |

---

## Support

If you encounter issues:
1. Check the **Flutter console** for error logs
2. Check the **Backend console** (`npm start` window) for proxy errors
3. Verify all steps in this guide were followed in order
4. Ensure no firewall blocks localhost:3001

The AI assistant will work in **offline mode** regardless of API configuration — it just won't have real AI responses.