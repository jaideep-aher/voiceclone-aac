# VoiceClone AAC

> An iOS **Augmentative & Alternative Communication (AAC)** app for people with ALS and other speech-affecting conditions. Record a short voice sample → get a **personalised cloned voice** via ElevenLabs → type or tap phrases to speak in your own voice.

[![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)](https://swift.org)
[![Node.js](https://img.shields.io/badge/Node.js-20+-green?logo=nodedotjs)](https://nodejs.org)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.8-blue?logo=typescript)](https://www.typescriptlang.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017+-lightgrey?logo=apple)](https://developer.apple.com)

---

## What It Does

1. **Sign up** with email/password or Sign in with Apple
2. **Record 10–30 seconds** of your voice (or upload an existing clip)
3. ElevenLabs **clones your voice** in ~10 seconds
4. **Type anything** or tap saved phrases → spoken back in your own voice
5. Works **offline** — frequently used phrases are cached on-device

---

## Stack

| Layer | Technology | Purpose |
|---|---|---|
| **iOS App** | SwiftUI, Swift 6, Core Data | UI, offline cache, audio playback |
| **Backend API** | Node.js 20, Express, TypeScript | Auth proxy, voice clone, TTS, phrase CRUD |
| **Auth + Database** | Supabase (PostgreSQL + Auth) | User accounts, phrase library, RLS policies |
| **Voice AI** | ElevenLabs API | Voice cloning + text-to-speech synthesis |
| **Deployment** | Railway (backend) | Dockerised API hosting |
| **Privacy Policy** | GitHub Pages | Hosted at `/docs/privacy-policy.html` |

---

## Features

### iOS App
- **Email/password + Sign in with Apple** authentication
- **Voice setup flow** — record live or upload an existing `.m4a / .mp3 / .wav`
- **Home screen** with:
  - Free-text input → Speak button
  - Quick Phrases bar (Yes, No, Help, Water, etc.) — always cached offline
  - Phrase library with categories (Medical, Family, Daily, Emergency, Custom)
  - **Search** — instant filter across all saved phrases
  - **Swipe to delete** phrases
  - **Stop button** — interrupt audio mid-sentence
  - Category chips for filtering (client-side, no extra API calls)
- **Offline mode** — banner when disconnected, queues pending synthesis, plays cached audio
- **On-device audio cache** — SHA256-keyed `.mp3` files + Core Data metadata, 500MB LRU eviction
- **Pre-cache** — quick phrases synthesised immediately after voice setup for guaranteed offline use
- **Settings** — voice speed (0.5×–2×), text size, high contrast, cache management, re-record voice, sign out, delete account
- **Accessibility** — all elements have `accessibilityLabel`, min 44pt tap targets, Dynamic Type support

### Backend API
- `POST /api/auth/signup` — create account + Supabase profile
- `POST /api/auth/login` — email/password sign in
- `POST /api/auth/apple` — Sign in with Apple (identity token)
- `GET /api/profile` — fetch user profile + voice clone status
- `GET /api/phrases` — list all phrases (sorted by use count)
- `POST /api/phrases` — create phrase
- `PUT /api/phrases/:id` — update phrase text/category
- `DELETE /api/phrases/:id` — delete phrase
- `GET /api/voice/status` — check voice clone status
- `POST /api/voice/clone` — upload audio → ElevenLabs voice clone
- `DELETE /api/voice/clone` — delete voice clone from ElevenLabs + profile
- `POST /api/voice/synthesize` — text → MP3 streamed back to client
- `GET /health` — health check

### Security
- JWT validated on every request via `supabase.auth.getUser()`
- Row Level Security on all Supabase tables — users can only see their own data
- `helmet` security headers + `express-rate-limit` (60 req/min per user, 429 on breach)
- Tokens stored in iOS Keychain — never in source code or UserDefaults
- `SUPABASE_SERVICE_ROLE_KEY` stays server-side only — never shipped in the app bundle
- Multi-stage Docker build — no dev dependencies in production image

---

## Project Structure

```
voiceclone-aac/
├── VoiceCloneAAC/                   # iOS app (SwiftUI)
│   ├── App/
│   │   ├── VoiceCloneAACApp.swift   # Entry point, environment setup
│   │   └── RootFlowView.swift       # Auth-state router
│   ├── Models/
│   │   ├── Phrase.swift             # Codable phrase model
│   │   ├── User.swift               # AuthSession, UserProfile models
│   │   ├── VoiceClone.swift         # VoiceCloneResult, VoiceStatusResponse
│   │   └── CoreDataModels.swift     # CachedAudio, PendingSynthesis
│   ├── Services/
│   │   ├── APIService.swift         # Actor-isolated HTTP client
│   │   ├── AudioService.swift       # AVFoundation recording + playback
│   │   ├── AudioCacheStore.swift    # On-device MP3 cache + LRU eviction
│   │   ├── PreCacheCoordinator.swift# Background quick-phrase pre-caching
│   │   ├── NetworkMonitor.swift     # NWPathMonitor online/offline state
│   │   └── PersistenceController.swift # Core Data stack
│   ├── ViewModels/
│   │   ├── AuthViewModel.swift      # App-wide auth state + routing
│   │   ├── HomeViewModel.swift      # Phrase list, speak, search, delete
│   │   └── VoiceSetupViewModel.swift# Recording, upload, clone flow
│   ├── Views/
│   │   ├── Onboarding/              # WelcomeView, SignUpView, VoiceSetupView
│   │   ├── Home/                    # HomeView, TextInputView, QuickPhrasesView, RecentPhrasesView
│   │   ├── Settings/                # SettingsView
│   │   └── Components/              # PhraseCard, SpeakButton, WaveformView
│   └── Utilities/
│       ├── Constants.swift          # API URL, default phrases, cache limits
│       ├── KeychainHelper.swift     # JWT token read/write/delete
│       └── TextHashing.swift        # SHA256 phrase key derivation
├── VoiceCloneAAC.xcodeproj/
├── backend/                         # Node.js API
│   ├── src/
│   │   ├── server.ts                # Entry point
│   │   ├── app.ts                   # Express setup, middleware chain
│   │   ├── config.ts                # Env var loading + assertConfig()
│   │   ├── routes/                  # auth, profile, phrases, voice, health
│   │   ├── middleware/              # auth.ts, rateLimit.ts, errorHandler.ts
│   │   ├── lib/                     # elevenlabs.ts, supabase.ts
│   │   ├── validation/              # Zod schemas for all request bodies
│   │   ├── errors/AppError.ts
│   │   └── utils/asyncHandler.ts
│   ├── Dockerfile                   # Multi-stage production build
│   ├── railway.toml                 # Railway deployment config
│   └── .env.example
├── supabase/
│   └── migrations/
│       └── 20260422120000_voiceclone_schema.sql
├── docs/
│   ├── ARCHITECTURE.md              # System design + Mermaid flowcharts
│   ├── SETUP_ENV_AND_STATUS.md      # Env vars reference + API docs
│   ├── INSTALL_ON_IPHONE.md         # Physical device install steps
│   ├── VoiceClone-AAC-Architecture-Plan.md
│   └── privacy-policy.html          # Hosted via GitHub Pages
└── scripts/
    └── build-ios.sh                 # xcodebuild simulator wrapper
```

---

## Getting Started

### Prerequisites

| Tool | Version | Where |
|---|---|---|
| Xcode | 16+ | Mac App Store |
| Node.js | 20+ | nodejs.org |
| Supabase account | free | supabase.com |
| ElevenLabs account | free tier | elevenlabs.io |
| Railway account | free tier | railway.app |

---

### Step 1 — Supabase Setup (5 min)

1. Create a new project at **supabase.com**
2. Go to **SQL Editor** → paste and run `supabase/migrations/20260422120000_voiceclone_schema.sql`
3. Go to **Storage** → create a bucket named **`voiceclone-aac`** (private)
4. Go to **Settings → API** → copy:
   - `Project URL`
   - `anon / public` key
   - `service_role` key (click reveal)

---

### Step 2 — Backend (Railway)

```bash
cd backend
npm install

# Local dev
cp .env.example .env
# Fill in .env with your Supabase + ElevenLabs keys
npm run dev
# → http://localhost:3000/health
```

**Deploy to Railway:**
```bash
railway login        # opens browser
railway init         # create new project
railway up           # deploys via Dockerfile
```

Set these environment variables in the Railway dashboard:

```
SUPABASE_URL               = https://your-project.supabase.co
SUPABASE_ANON_KEY          = eyJ...
SUPABASE_SERVICE_ROLE_KEY  = eyJ...
ELEVENLABS_API_KEY         = sk_...
CORS_ORIGINS               = *
NODE_ENV                   = production
PORT                       = 3000
```

Railway gives you a URL like `https://voiceclone-aac.up.railway.app`. Copy it — you need it for the iOS app.

---

### Step 3 — iOS App (Xcode)

1. Open **`VoiceCloneAAC.xcodeproj`** in Xcode
2. Open `VoiceCloneAAC/Utilities/Constants.swift` and set your Railway URL:
   ```swift
   return "https://voiceclone-aac.up.railway.app"
   ```
3. Click the project → **Signing & Capabilities** → enable **Automatically manage signing** → pick your Apple Developer team (add your Apple ID under Xcode **Settings → Accounts** if needed)
4. Plug in your iPhone → select it as the run destination → **⌘R**
5. On first launch: **Settings → General → VPN & Device Management → [your Apple ID] → Trust**

**Enable Developer Mode on iPhone first:**
Settings → Privacy & Security → Developer Mode → ON (requires restart)

---

### Step 4 — Run the App

1. Sign up with email + password
2. Record 10–30 seconds of your voice reading the sample sentence
3. Wait ~10 seconds for ElevenLabs to clone your voice
4. Tap any phrase or type freely — it speaks back in your voice

---

## Environment Variables Reference

| Variable | Required | Description |
|---|---|---|
| `SUPABASE_URL` | ✅ | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | ✅ | Public anon key (safe for client) |
| `SUPABASE_SERVICE_ROLE_KEY` | ✅ | Admin key — server only, never expose |
| `ELEVENLABS_API_KEY` | ✅ | ElevenLabs API key for voice clone + TTS |
| `SUPABASE_VOICE_BUCKET` | optional | Storage bucket name (default: `voiceclone-aac`) |
| `CORS_ORIGINS` | optional | Comma-separated allowed origins (default: `*`) |
| `PORT` | optional | Server port (default: `3000`) |
| `NODE_ENV` | optional | Set to `production` on Railway |

---

## Market Context

The AAC app market is valued at **$1.79B (2024)**, growing at **13.2% CAGR** to $5.38B by 2033. Key competitors (Proloquo2Go at $249.99, TouchChat at $149.99) are iOS-only and do not offer personalised voice cloning — they use generic TTS voices. VoiceClone AAC is differentiated by letting users speak in their **own voice**.

---

## Roadmap

- [ ] **Edit phrase** — fix typos in saved phrases
- [ ] **Token refresh** — auto-renew session without signing out
- [ ] **Large-button Simple Mode** — oversized tap targets as motor control declines
- [ ] **Caregiver mode** — family member pre-populates phrase library remotely
- [ ] **Export phrases** — download phrase library as CSV
- [ ] **App Store submission** — Apple Developer Program ($99/yr), India Pvt Ltd entity supported
- [ ] **In-App Purchases** — monthly subscription via StoreKit 2

---

## Documentation

| Doc | Contents |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design, component map, Mermaid flowcharts |
| [docs/SETUP_ENV_AND_STATUS.md](docs/SETUP_ENV_AND_STATUS.md) | Full env var reference, HTTP API docs |
| [docs/INSTALL_ON_IPHONE.md](docs/INSTALL_ON_IPHONE.md) | Physical iPhone install steps |
| [docs/privacy-policy.html](docs/privacy-policy.html) | Privacy policy (hosted via GitHub Pages) |

---

## License

Proprietary — © 2026 Aher Technologies Private Limited. All rights reserved.
