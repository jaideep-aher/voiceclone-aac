# Architecture and flows — VoiceClone AAC

Technical overview of the **iOS client**, **Express backend**, **Supabase**, and **ElevenLabs**, with **sequence diagrams** for the main user journeys.

---

## 1. System context

```mermaid
flowchart TB
  subgraph device["User device"]
    APP[VoiceCloneAAC SwiftUI]
    FS[FileManager MP3 cache]
    CD[(Core Data)]
  end
  subgraph cloud["Your infrastructure"]
    API[Express API]
  end
  subgraph supa["Supabase"]
    AUTH[Auth / JWT]
    DB[(Postgres)]
    ST[Storage]
  end
  EL[ElevenLabs API]

  APP <-->|HTTPS| API
  APP --> FS
  APP --> CD
  API --> AUTH
  API --> DB
  API --> ST
  API --> EL
```

**Trust boundaries**

- The **JWT** never leaves the device except as `Authorization` to your API.
- **Service role** and **ElevenLabs** keys exist only on the server.

---

## 2. iOS app layers (logical)

```mermaid
flowchart LR
  subgraph ui["Views"]
    W[Welcome / SignUp]
    VS[VoiceSetup]
    H[Home]
    ST[Settings]
  end
  subgraph vm["ViewModels"]
    AV[AuthViewModel]
    HV[HomeViewModel]
    VSV[VoiceSetupViewModel]
  end
  subgraph services["Services"]
    APIc[APIService]
    AUD[AudioService]
    CACHE[AudioCacheStore]
    NET[NetworkMonitor]
    PRE[PreCacheCoordinator]
  end
  ui --> vm
  vm --> APIc
  vm --> AUD
  vm --> CACHE
  CACHE --> CD[(Core Data)]
  CACHE --> FS[MP3 files]
  NET -.->|isConnected| vm
  PRE --> APIc
  PRE --> CACHE
```

| Component | Responsibility |
|-----------|----------------|
| **APIService** | Async HTTP to Express; JWT from Keychain |
| **AudioCacheStore** | Save/load MP3 by phrase hash; pending queue; LRU; totals |
| **NetworkMonitor** | `NWPathMonitor` → published online/offline |
| **PreCacheCoordinator** | After clone success, batch-fetch quick phrases into cache |
| **PersistenceController** | `NSPersistentContainer` for `VoiceCloneCache` model |

---

## 3. Authentication flow (email or Apple)

```mermaid
sequenceDiagram
  participant U as User
  participant iOS as iOS app
  participant API as Express API
  participant SA as Supabase Auth

  U->>iOS: Sign up / Sign in
  alt Email password
    iOS->>API: POST /api/auth/signup or /login
    API->>SA: admin create user OR anon signInWithPassword
    SA-->>API: session (access_token, refresh_token, user)
    API-->>iOS: JSON session
  else Sign in with Apple
    iOS->>iOS: ASAuthorizationAppleIDCredential
    iOS->>API: POST /api/auth/apple { id_token, nonce? }
    API->>SA: signInWithIdToken(provider apple)
    SA-->>API: session + user
    API->>API: ensure profile row exists
    API-->>iOS: JSON session
  end
  iOS->>iOS: Keychain store access_token
  iOS->>API: subsequent calls Authorization Bearer
```

After login, **AuthViewModel** loads **profile** (`GET /api/profile`) for `voiceCloneId` and routing (onboarding vs home).

---

## 4. Voice clone flow

```mermaid
sequenceDiagram
  participant U as User
  participant iOS as iOS app
  participant API as Express API
  participant ST as Supabase Storage
  participant EL as ElevenLabs
  participant DB as Postgres

  U->>iOS: Record or pick audio file
  iOS->>API: POST /api/voice/clone multipart file
  API->>API: validate mime/size, optional metadata parse
  API->>ST: upload sample (implementation-specific path)
  API->>EL: create instant voice clone from audio
  EL-->>API: voice_id
  API->>DB: update profiles.voice_clone_id, status active
  API-->>iOS: VoiceCloneResult JSON
  iOS->>iOS: VoiceSetup previewSuccess + start PreCacheCoordinator
  loop Quick phrases
    iOS->>API: POST /api/voice/synthesize
    API->>EL: TTS with cloned voice_id
    EL-->>API: audio
    API-->>iOS: MP3 bytes
    iOS->>iOS: AudioCacheStore.saveAudio (disk + Core Data)
  end
```

**Stale voice handling:** when the active `voiceCloneId` changes, the app can **purge** cache rows for other voice IDs (`purgeStaleVoiceCaches`).

---

## 5. Speak / synthesize flow (online, with cache)

```mermaid
sequenceDiagram
  participant U as User
  participant iOS as HomeViewModel
  participant CACHE as AudioCacheStore
  participant API as Express API
  participant AUD as AudioService

  U->>iOS: Tap phrase or Speak
  iOS->>CACHE: loadAudioData(text, voiceId)
  alt Cache hit
    CACHE-->>iOS: MP3 Data
    iOS->>AUD: play(data)
  else Cache miss and online
    iOS->>API: POST /api/voice/synthesize
    API-->>iOS: MP3 Data
    iOS->>CACHE: saveAudio (writes file, Core Data, LRU)
    iOS->>AUD: play(data)
  else Cache miss and offline
    iOS->>CACHE: enqueuePending (Core Data)
    iOS-->>U: UI: will synthesize when online
  end
```

**File naming:** `{SHA256(normalized_text)}.mp3` under Application Support, keyed in **CachedAudio** by `textHash` + `voiceId`.

---

## 6. Offline queue and reconnect

```mermaid
stateDiagram-v2
  [*] --> Online
  Online --> Offline: NWPath unsatisfied
  Offline --> Online: NWPath satisfied
  state Offline
    NewSpeak: enqueue PendingSynthesis
    CachedSpeak: play from disk
  end
  Online: processPendingQueue synthesize + saveAudio
  Online: dismiss banner / toast Back online
```

- **PendingSynthesis** stores normalized text, category, `createdAt`, `status` (`pending` | `failed`).
- On reconnect, **HomeView** triggers **processPendingQueue** (sequential synthesize + delete pending row).

---

## 7. Data stores

### Postgres (Supabase)

| Table | Role |
|-------|------|
| `profiles` | `display_name`, `voice_clone_id`, `voice_clone_status` |
| `phrases` | User phrase library, categories, `last_used_at` |
| `voice_samples` | Metadata / URLs for uploaded samples |

RLS policies scope rows to `auth.uid()` for direct client access; the **API uses service role** and still enforces `req.userId` from JWT.

### Core Data (device)

| Entity | Role |
|--------|------|
| **CachedAudio** | `text`, `textHash`, `localFilePath`, `voiceId`, `fileSize`, timestamps |
| **PendingSynthesis** | Offline queue rows |

### Disk

- MP3 files in app sandbox (Application Support subdirectory), excluded from iCloud unless you change file URLs.

---

## 8. Backend route mounting

Express mounts:

- `/health` — public
- `/api/auth/*` — auth router
- `/api/profile`, `/api/phrases`, `/api/voice/*` — authenticated routers (see `app.ts`)

Global middleware: helmet, CORS, JSON body limit, API rate limiter, centralized error handler.

---

## 9. Diagram: end-to-end “first launch”

```mermaid
flowchart TD
  A[Launch app] --> B{JWT in Keychain?}
  B -->|No| C[Welcome / Sign up]
  B -->|Yes| D[Fetch profile]
  C --> D
  D --> E{voice_clone_status}
  E -->|none / needs setup| F[VoiceSetupView]
  E -->|active| G[HomeView]
  F --> H[Clone voice]
  H --> I[Pre-cache quick phrases]
  I --> G
  G --> J[Speak / cache / offline]
```

---

## 10. Further reading

- Environment and API tables: **[SETUP_ENV_AND_STATUS.md](./SETUP_ENV_AND_STATUS.md)**
- Product/planning notes: **[VoiceClone-AAC-Architecture-Plan.md](./VoiceClone-AAC-Architecture-Plan.md)**
