# VoiceClone AAC App — Full Architecture & Development Plan

**Project:** Voice cloning AAC (Augmentative & Alternative Communication) app for iOS  
**Target user:** People with speech impairments (ALS/MND, stroke, autism, etc.)  
**Date:** April 22, 2026  
**Status:** MVP Build Plan

---

## 1. Competitive Landscape — Top 10 Apps

| # | App | What they do | Weakness |
|---|-----|--------------|----------|
| 1 | VoiceBack (Sleepme Inc.) | Voice clone from 10–15s sample, type-to-speak AAC | No real-time streaming, basic UI, no offline mode, limited phrase management |
| 2 | Talk to Me, Goose! | AI voice cloning for ALS via Live Like Lou foundation | Free but limited customization, no phrase caching |
| 3 | ElevenLabs (direct) | Best-in-class TTS + voice cloning platform | Not an AAC app — tool, not purpose-built for impaired users |
| 4 | Descript | Voice cloning inside video/audio editor | Designed for content creators, not AAC users |
| 5 | Murf AI | Studio-quality voice cloning | Enterprise-focused, no AAC features, expensive |
| 6 | Resemble AI | Enterprise voice cloning with emotion control | API-first, no consumer app, complex setup |
| 7 | PlayHT | Cross-language voice cloning (140+ languages) | Higher latency (~300ms), no offline mode |
| 8 | Predictable (Therapy Box) | AAC app with symbol/text communication | No voice cloning — generic system voices |
| 9 | TD Snap (Tobii Dynavox) | Full AAC with eye-tracking integration | Expensive hardware required, no personal voice clone |
| 10 | AssistiveWare Proloquo | Symbol-based AAC for autism/CP | No voice cloning; symbol boards, not typed speech |

### What competitors lack (product edge)

- **Offline-first phrase caching** — most need internet for every synthesis  
- **Sub-100ms latency on cloned voice** — most are 300ms+  
- **ALS-optimized keyboard** — large keys, word prediction, phrase shortcuts  
- **Privacy-first architecture** — voice data stays on device, not perpetually shipped to third parties  
- **Family sharing** — caregiver can set up phrases remotely  
- **Progressive degradation support** — as ALS progresses, the app adapts (eye tracking path, switch access)

---

## 2. API Selection: ElevenLabs (Primary) + Fish Audio (Fallback)

### ElevenLabs as primary

- Gold standard voice quality — wins blind tests ~37% vs competitors  
- Flash v2.5: ~75ms latency, 32 languages  
- Instant voice cloning from ~60 seconds of audio (works for limited voice capacity)  
- Well-documented API, large community, proven at scale  
- Starter ~$5/month includes commercial rights and instant cloning  

### Fish Audio as fallback

- ~50% cheaper per character than ElevenLabs ($15/M vs $30/M characters)  
- Sub-100ms latency with streaming  
- Pay-as-you-go, no monthly minimums  
- Escape hatch if ElevenLabs cost at scale is too high  

### Pricing math — one ALS patient per month

**Assumptions**

- ~8 phrases synthesized per day  
- Average phrase ~50 characters; some ~150; **average ~80 characters** per synthesis  
- 8 × 80 = 640 characters/day → 640 × 30 = **19,200 characters/month** per user  

**ElevenLabs**

- Starter ($5/mo) includes 30,000 characters — covers one user  
- API Pro ($99/mo) with credits: headroom for more  
- Per-character API ballpark ~$0.30 per 1k chars → 19,200 × $0.0003 ≈ **$5.76/mo** raw API per user at that rate  

**Fish Audio**

- ~$15 per 1M UTF-8 bytes → 19,200 / 1,000,000 × 15 ≈ **$0.29/mo** raw per user  

**Bottom line:** Fish Audio is much cheaper per user; ElevenLabs prioritizes quality. Start with ElevenLabs; consider Fish Audio if scaling past ~100+ users and cost cutting is required.

---

## 3. Full Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    iOS App (SwiftUI)                     │
│                                                         │
│  ┌─────────┐  ┌──────────┐  ┌────────┐  ┌───────────┐ │
│  │ Onboard │  │ Voice    │  │ Type & │  │ Phrase    │ │
│  │ + Auth  │  │ Clone    │  │ Speak  │  │ Library   │ │
│  │ Screen  │  │ Setup    │  │ Screen │  │ + History │ │
│  └────┬────┘  └────┬─────┘  └───┬────┘  └─────┬─────┘ │
│       │            │            │              │       │
│  ┌────▼────────────▼────────────▼──────────────▼─────┐ │
│  │              Local Cache Layer                     │ │
│  │   Core Data: phrases, audio files, voice metadata│ │
│  │   FileManager: cached .mp3/.wav audio files      │ │
│  └────────────────────┬──────────────────────────────┘ │
└───────────────────────┼─────────────────────────────────┘
                        │ HTTPS
┌───────────────────────▼─────────────────────────────────┐
│         Backend API (Railway — Node.js/Express)           │
│                                                           │
│  POST /api/auth/signup        — create account            │
│  POST /api/auth/login         — login (JWT)               │
│  POST /api/voice/clone        — upload sample → clone     │
│  POST /api/voice/synthesize   — text → audio              │
│  GET  /api/phrases            — saved phrases             │
│  POST /api/phrases            — save phrase               │
│  POST /api/billing/subscribe  — (future) Apple Pay      │
│                                                           │
│  Middleware: auth, rate limiting, input validation        │
└──────┬──────────────┬───────────────┬─────────────────────┘
       │              │               │
┌──────▼──────┐ ┌─────▼─────┐ ┌──────▼──────┐
│  Supabase   │ │ ElevenLabs│ │  Supabase   │
│  Auth +     │ │ API       │ │  Storage    │
│  Postgres   │ │           │ │  (audio     │
│  (users,    │ │ - clone   │ │   files)    │
│   phrases,  │ │ - TTS     │ │             │
│   metadata) │ │           │ │             │
└─────────────┘ └───────────┘ └─────────────┘
```

### Tech stack

| Layer | Technology | Why |
|-------|------------|-----|
| iOS frontend | SwiftUI + Swift 5.9+ | Native iOS, performance, built-in accessibility |
| Backend API | Node.js + Express on Railway | Railway Premium; simple and fast |
| Auth | Supabase Auth | JWT, magic links, Apple Sign In |
| Database | Supabase Postgres | Profiles, phrase history, clone metadata |
| File storage | Supabase Storage | Voice samples, cached audio (cloud backup) |
| Voice clone API | ElevenLabs | Quality + TTS |
| Payments (future) | Apple StoreKit 2 | App Store subscriptions |
| Push (future) | APNs via Supabase | Caregiver alerts, reminders |

---

## 4. App Design — Screens & UX

### 4.1 Onboarding (first-time only)

**Screen 1 — Welcome**

- Headline: *Your Voice, Preserved.*  
- Subline: Clone with a 15-second recording; speak with your own voice.  
- CTA: **Get Started**

**Screen 2 — Create Account**

- Apple Sign In (primary)  
- Email + password (secondary)  
- Terms & Privacy copy  
- No extra social logins — medical/accessibility trust  

**Screen 3 — Voice clone setup**

- Headline: *Let's Capture Your Voice*  
- Quiet room; phone 6–8 inches from mouth  
- Sample sentence: *The quick brown fox jumps over the lazy dog. I love spending time with my family on sunny afternoons.*  
- Large record control; 15s timer + waveform  
- *Upload existing audio* for existing recordings  
- After record: preview + **Use This** / **Try Again**

**Screen 4 — Processing**

- *Creating your voice clone…* (~30–60s via ElevenLabs)  
- Done: play *Hello, this is your cloned voice*  
- CTA: **Sounds Great!** → Home  

### 4.2 Home (main daily use)

- Large type field; prominent **Speak**  
- **Quick phrases** — one-tap speak  
- **Recent** — from history  
- **+ Add phrase**  
- **Categories** — Medical, Family, Daily, Emergency, Custom  
- Offline indicator when cached phrases work without network  

### 4.3 Settings

- **My Voice** — re-record, listen, speed/pitch  
- **Quick phrases** — manage, add, reorder, categorize  
- **Accessibility** — font size, high contrast, switch access, dwell time  
- **Account** — email, password, sign out, delete account  
- **Subscription** (future) — Apple Pay  
- **About** — version, privacy, support  

### 4.4 Profile / voice management

- Clone status (active / processing)  
- **Re-clone Voice**  
- Speed 0.5x–2.0x; pitch  
- Quality: High (slower) vs Fast (lower quality, instant)  
- Local cache size (MB)

---

*End of architecture plan document.*
