# VoiceClone AAC

iOS **Augmentative & Alternative Communication (AAC)** app: users capture a short voice sample, get a **cloned voice** via [ElevenLabs](https://elevenlabs.io), then **type or tap phrases** to speak with that voice. Includes **local audio caching**, **Core Data**, and **offline-aware** behavior so cached phrases work without a network.

This repository contains:

| Part | Stack | Purpose |
|------|--------|---------|
| **VoiceCloneAAC/** | SwiftUI, iOS | Client app |
| **backend/** | Node.js, Express, TypeScript | BFF API: auth, phrases, voice clone, TTS |
| **supabase/migrations/** | PostgreSQL | Schema for profiles, phrases, voice samples |

**Public repo:** [github.com/jaideep-aher/voiceclone-aac](https://github.com/jaideep-aher/voiceclone-aac)

---

## Features (current)

- Email/password and **Sign in with Apple** (via Supabase)
- **Voice clone** from recorded or uploaded audio (multipart upload to API)
- **Phrase library** with categories; quick phrases + recent usage
- **Synthesized speech** returned as **MP3** from the backend
- **On-device cache**: SHA256-named `.mp3` files + Core Data (`CachedAudio`, `PendingSynthesis`)
- **Offline**: banner, queue pending synthesis, play cached audio without network
- **Pre-cache** default quick phrases after clone setup
- **Storage** settings: total cache size, clear history (keep quick phrases), LRU eviction at 500MB

---

## Documentation

| Document | Contents |
|----------|----------|
| **[docs/SETUP_ENV_AND_STATUS.md](docs/SETUP_ENV_AND_STATUS.md)** | Environment variables, where each secret comes from, HTTP API reference, **known gaps / next steps** |
| **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** | System design, component map, **Mermaid flowcharts** (auth, clone, speak, offline) |
| **[docs/VoiceClone-AAC-Architecture-Plan.md](docs/VoiceClone-AAC-Architecture-Plan.md)** | Original product/architecture planning notes (landscape, pricing notes) |

---

## Prerequisites

- **Xcode** 15+ (for the iOS app)
- **Node.js** 20+ (for the backend)
- **Supabase** project (Auth + Postgres + Storage)
- **ElevenLabs** API key with voice cloning / TTS access
- A host for the API (e.g. **Railway**, Fly.io, Render) or run locally for development

---

## Quick start — backend

```bash
cd backend
cp .env.example .env
# Edit .env — see docs/SETUP_ENV_AND_STATUS.md

npm install
npm run dev
```

Health check: `GET http://localhost:3000/health` → `{ "ok": true, "service": "voiceclone-aac-api" }`

Apply the SQL migration in the Supabase SQL editor (or your migration pipeline):

- `supabase/migrations/20260422120000_voiceclone_schema.sql`

Create a **Storage** bucket matching `SUPABASE_VOICE_BUCKET` (default `voiceclone-aac`) and configure policies as needed for your security model.

---

## Quick start — iOS

1. Open **`VoiceCloneAAC.xcodeproj`** in Xcode.
2. Set **`VoiceCloneAAC/Utilities/Constants.swift`** → `apiBaseURLString` to your deployed API **origin** (no trailing slash), e.g. `https://your-service.up.railway.app`.
3. Configure **Signing & Capabilities** for your Apple Developer team.
4. For **Sign in with Apple**, enable the capability in Xcode and configure the **Apple** provider + redirect URLs in the Supabase dashboard (see setup doc).
5. Build and run (simulator or device).

---

## Repository layout

```
voiceclone-aac/
├── VoiceCloneAAC/           # SwiftUI app sources
├── VoiceCloneAAC.xcodeproj/
├── backend/
│   ├── src/                 # Express routes, ElevenLabs + Supabase integration
│   ├── scripts/             # curl / test helpers
│   └── .env.example
├── supabase/migrations/
├── docs/
│   ├── SETUP_ENV_AND_STATUS.md
│   ├── ARCHITECTURE.md
│   └── VoiceClone-AAC-Architecture-Plan.md
└── README.md
```

---

## Security notes

- Never commit **`.env`** or real API keys. The backend expects secrets only via environment variables.
- The iOS app stores the **Supabase JWT** (from your API) in the **Keychain** — not in source control.
- **`SUPABASE_SERVICE_ROLE_KEY`** must stay **server-only** (Railway/host secrets), never in the app bundle.

---

## License

Specify your license here (e.g. MIT) if you open-source the project publicly.
