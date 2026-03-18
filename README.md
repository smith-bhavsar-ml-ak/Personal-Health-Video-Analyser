# Personal Health Video Analyzer (PHVA)

AI-powered fitness coaching app that analyzes exercise form from video, tracks progress over time, and generates personalized workout plans — all running locally with no cloud dependency.

---

## Table of Contents

1. [Business Overview](#1-business-overview)
2. [Feature Set](#2-feature-set)
3. [Architecture](#3-architecture)
4. [Repository Structure](#4-repository-structure)
5. [Backend Deep Dive](#5-backend-deep-dive)
   - 5.1 [Auth & Users](#51-auth--users)
   - 5.2 [Video Analysis Pipeline](#52-video-analysis-pipeline)
   - 5.3 [BiLSTM Exercise Classifier](#53-bilstm-exercise-classifier)
   - 5.4 [LLM Coaching (Groq)](#54-llm-coaching-groq)
   - 5.5 [Voice Assistant (STT / TTS)](#55-voice-assistant-stt--tts)
   - 5.6 [Progress Tracking API](#56-progress-tracking-api)
   - 5.7 [Workout Plans API](#57-workout-plans-api)
   - 5.8 [Database Layer](#58-database-layer)
6. [Database Schema](#6-database-schema)
7. [Flutter App Deep Dive](#7-flutter-app-deep-dive)
   - 7.1 [Navigation & Shell](#71-navigation--shell)
   - 7.2 [Screens](#72-screens)
   - 7.3 [State Management](#73-state-management)
   - 7.4 [API Client](#74-api-client)
   - 7.5 [Design System](#75-design-system)
8. [Full Request Flows](#8-full-request-flows)
9. [Environment & Configuration](#9-environment--configuration)
10. [Docker Setup](#10-docker-setup)
11. [Development Commands](#11-development-commands)
12. [Design Decisions](#12-design-decisions)

---

## 1. Business Overview

PHVA is a **subscription-ready personal fitness coach** that runs entirely on-device or self-hosted — no cloud APIs, no data leaving the user's infrastructure.

### Value Proposition

| Problem | PHVA Solution |
|---------|--------------|
| Gym members can't afford a personal trainer | AI form coaching at a fraction of the cost |
| Hard to self-assess exercise form | Computer vision scores every rep objectively |
| Generic workout programs don't adapt to the user | LLM generates personalised plans from health profile |
| Progress tracking is fragmented across apps | Unified weight, form score, and rep trends in one place |
| Privacy concerns with cloud fitness apps | All processing runs locally (Ollama + MediaPipe + Whisper) |

### Target Users

- **Individual fitness enthusiasts** who work out at home or in a gym and want form feedback without a trainer
- **Personal trainers** who want an objective tool to show clients their progress over time
- **Physiotherapy clinics** tracking patient movement quality during rehabilitation

### Subscription Model Levers

- **Free tier:** 3 video analyses/month, no history export, no AI plans
- **Pro tier:** Unlimited analysis, full history, AI-generated plans, voice coach, progress charts
- **Clinic tier:** Multi-user, patient management, exportable PDF reports

---

## 2. Feature Set

### Video Analysis
Upload any exercise video (phone camera, webcam recording, screen recording from a fitness app). The system:
1. Extracts frames at 10 fps using OpenCV
2. Runs MediaPipe Pose to detect 33 body landmarks per frame
3. Feeds the landmark sequence through a **BiLSTM neural network** to classify the exercise
4. Runs a rule-based analyser (specific to the detected exercise) to count reps, score form per rep, and identify posture errors
5. Sends the structured workout data to a local **Ollama LLM** (llama3.2) for natural-language coaching feedback
6. Returns the full result in ~5–15 seconds depending on video length

### Rep-Level Feedback
Every rep gets an individual form score. The session detail screen shows:
- A bar chart of rep scores across the set
- Colour-coded quality pills (R1 92% / R3 71% etc.)
- Posture error rows with severity indicators (low / medium / high)

### Progress Tracking
Dashboard charts showing trends over all sessions:
- **Weight over time** — manual weight logging with line chart
- **Form score trend** — rolling average per session
- **Exercise breakdown** — reps, avg form score, and correct-rep accuracy per exercise type

### Workout Plans
AI-generated weekly training schedules based on the user's fitness profile (goal, level, equipment, injury notes). Each plan:
- Covers 2–8 weeks, 3–5 workout days/week
- Lists sets, reps, and duration targets per exercise per day
- Allows tapping individual exercises to mark them complete
- Falls back to a template plan if the LLM is unavailable

### Exercise Library
Static reference pages for all supported exercises (Squat, Lunge, Bicep Curl, Jumping Jack, Plank), each with:
- Muscle groups targeted
- Step-by-step form cues
- Common mistakes to avoid

### Voice AI Coach
Ask natural-language questions about any session. Input can be:
- **Text** — typed in the chat interface
- **Voice** — recorded audio → Whisper STT → Ollama LLM → pyttsx3 TTS playback

Suggested question chips and full Q&A history per session.

### Social Sharing
Share a session summary (date, form score, reps, exercises) as plain text to any app via the OS share sheet (iOS / Android) or clipboard (web).

---

## 3. Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                  Flutter App (iOS · Android · Web)               │
│                                                                  │
│  Home  Analyze  History  Progress  Plans  Library  Assistant     │
│                                                                  │
│  Riverpod state  ·  GoRouter navigation  ·  Dio HTTP client      │
└────────────────────────────┬─────────────────────────────────────┘
                             │  JWT Bearer  ·  multipart/json
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│             Nginx  (reverse proxy + static web build)            │
│       /api/ → backend:8000     /  → Flutter web (SPA)           │
└──────────────┬──────────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────────────┐
│                  FastAPI  (Python 3.11, port 8000)               │
│                                                                  │
│  /api/v1/auth        /api/v1/sessions    /api/v1/progress        │
│  /api/v1/profile     /api/v1/voice       /api/v1/plans           │
│                                                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌───────────────────┐  │
│  │  CV Pipeline   │  │  Ollama LLM    │  │  Voice (Whisper + │  │
│  │  OpenCV        │  │  llama3.2      │  │  pyttsx3 TTS)     │  │
│  │  MediaPipe     │  │  port 11434    │  └───────────────────┘  │
│  │  BiLSTM model  │  └────────────────┘                         │
│  └────────────────┘                                             │
└───────────────────────────────┬──────────────────────────────────┘
                                │  asyncpg
                                ▼
                   ┌────────────────────────┐
                   │   PostgreSQL 16         │
                   │   (Docker volume)       │
                   └────────────────────────┘
```

---

## 4. Repository Structure

```
Personal Health Video Analyzer/
│
├── backend/                         # Python / FastAPI
│   ├── app/
│   │   ├── main.py                  # App bootstrap, CORS, rate limiter, DB init
│   │   ├── api/
│   │   │   ├── router.py            # Aggregates all sub-routers
│   │   │   ├── sessions.py          # Video upload, list, get, delete
│   │   │   ├── voice.py             # STT + LLM + TTS endpoint
│   │   │   ├── progress.py          # Weight log, form trend, exercise stats
│   │   │   └── plans.py             # AI plan generation + CRUD
│   │   ├── auth/
│   │   │   ├── routes.py            # /auth/login, /auth/register, /auth/me
│   │   │   └── deps.py              # get_current_user JWT dependency
│   │   ├── cv/
│   │   │   ├── frame_extractor.py   # OpenCV: video → sampled frames
│   │   │   ├── pose_detector.py     # MediaPipe: frames → PoseFrame list
│   │   │   └── pipeline.py          # Chains extractor + detector
│   │   ├── analysis/
│   │   │   ├── base.py              # Abstract ExerciseAnalyser
│   │   │   ├── rule_based.py        # Dispatcher (classifies → delegates)
│   │   │   ├── bilstm_model.py      # PyTorch BiLSTM architecture
│   │   │   ├── bilstm_analyser.py   # Inference: BiLSTM + physics checks
│   │   │   ├── features.py          # 14-dim feature vector extractor
│   │   │   ├── aggregator.py        # Merges exercise results → session summary
│   │   │   ├── train_bilstm.py      # Training script (synthetic/real/mixed)
│   │   │   ├── preprocess_real_data.py
│   │   │   ├── evaluate_bilstm.py
│   │   │   ├── weights/
│   │   │   │   └── bilstm_classifier.pt
│   │   │   └── exercises/
│   │   │       ├── squat.py
│   │   │       ├── jumping_jack.py
│   │   │       ├── bicep_curl.py
│   │   │       ├── lunge.py
│   │   │       └── plank.py
│   │   ├── feedback/
│   │   │   └── llm.py               # Ollama client (feedback + plans + queries)
│   │   ├── voice/
│   │   │   ├── stt.py               # Whisper transcription
│   │   │   └── tts.py               # pyttsx3 synthesis
│   │   ├── db/
│   │   │   ├── database.py          # Async SQLAlchemy engine
│   │   │   ├── models.py            # ORM table definitions
│   │   │   └── crud.py              # All DB operations
│   │   └── schemas/
│   │       └── session.py           # Pydantic response schemas
│   ├── alembic/
│   │   └── versions/
│   │       ├── 001_initial.py
│   │       ├── 002_auth_profile.py
│   │       └── 003_progress_plans.py
│   ├── tests/                       # pytest (72 passed, 1 xfailed)
│   ├── requirements.txt
│   └── Dockerfile
│
├── app/                             # Flutter (iOS · Android · Web)
│   └── lib/
│       ├── main.dart                # ProviderScope, usePathUrlStrategy (web)
│       ├── app.dart                 # GoRouter + MaterialApp.router
│       ├── core/
│       │   ├── api/
│       │   │   ├── client.dart      # Dio singleton + auth interceptor
│       │   │   └── api_service.dart # All API call methods
│       │   ├── models/              # Dart models with fromJson
│       │   ├── storage/
│       │   │   └── secure_storage.dart
│       │   └── theme/
│       │       ├── app_theme.dart   # Dark + light MaterialTheme
│       │       └── exercise_helpers.dart
│       ├── features/
│       │   ├── auth/
│       │   ├── home/
│       │   ├── analyze/
│       │   ├── sessions/            # history_screen + session_detail_screen
│       │   ├── assistant/
│       │   ├── progress/            # Progress charts + weight logging
│       │   ├── plans/               # Plan list + AI generation + detail
│       │   ├── library/             # Exercise reference pages
│       │   ├── settings/
│       │   └── profile/
│       └── widgets/
│           ├── app_shell.dart       # Adaptive sidebar / bottom nav shell
│           ├── side_nav.dart        # 240px fixed sidebar (web/tablet)
│           ├── bottom_nav.dart      # 5-tab bottom bar (mobile)
│           ├── exercise_card.dart   # Expandable set card + rep chart
│           ├── ai_feedback_panel.dart
│           ├── score_ring.dart
│           └── exercise_badge.dart
│
├── design-system/
│   └── MASTER.md                    # Design tokens, color palette, component specs
├── docker-compose.yml               # Production stack
├── docker-compose.dev.yml           # Dev stack (hot reload)
└── CLAUDE.md                        # AI assistant instructions for this repo
```

---

## 5. Backend Deep Dive

### 5.1 Auth & Users

JWT-based authentication. All `/api/v1` endpoints (except `/auth/login` and `/auth/register`) require a `Bearer <token>` header, enforced by the `get_current_user` FastAPI dependency.

| Endpoint | Description |
|----------|-------------|
| `POST /api/v1/auth/register` | Creates user + hashed password, returns JWT |
| `POST /api/v1/auth/login` | Verifies credentials, returns JWT |
| `GET  /api/v1/auth/me` | Returns current user info |
| `GET/PUT /api/v1/profile` | User fitness profile (goal, level, equipment, injuries) |

The profile drives both **plan generation** (LLM is given the profile as context) and future personalised coaching.

---

### 5.2 Video Analysis Pipeline

`POST /api/v1/sessions/analyze` is the core endpoint. It accepts a multipart video file, runs the full pipeline as a **background task**, and returns immediately with `status="processing"`. The client polls `GET /sessions/{id}` until status is `completed` or `failed`.

```
Upload video
    │
    ├─ 1. create_session() → status = "processing"
    │
    ├─ 2. CV Pipeline (frame_extractor + pose_detector)
    │       OpenCV samples frames at 10 fps
    │       MediaPipe extracts 33 landmarks per frame
    │
    ├─ 3. BiLSTM Classifier
    │       14-dim feature vector per frame
    │       Predicts exercise type + confidence
    │       Physics check validates prediction
    │       Falls back to rule-based classifier if confidence < 0.40
    │
    ├─ 4. Rule-based Analyser (exercise-specific)
    │       Counts reps via angle/position thresholds
    │       Scores form per rep (0–100)
    │       Detects posture errors per frame
    │       Builds rep_scores[] array
    │
    ├─ 5. Aggregator
    │       Merges results → session summary
    │       Includes rep_scores[] per exercise set
    │
    ├─ 6. LLM Feedback (Ollama llama3.2)
    │       Structured workout context → coaching text
    │
    ├─ 7. Persist to PostgreSQL
    │       sessions, exercise_sets (+ rep_scores JSON),
    │       posture_errors, ai_feedback
    │       status = "completed"
    │
    └─ 8. Client polls GET /sessions/{id} → receives full result
```

---

### 5.3 BiLSTM Exercise Classifier

A PyTorch Bidirectional LSTM that classifies exercise type from a sequence of pose frames. It replaces the older purely rule-based classification, giving higher accuracy and extensibility to new exercises without code changes.

**Architecture:**
```
Input (batch, T, 14)  →  BiLSTM (hidden=128, layers=2, bidirectional)
  →  Mean-pool over time  →  Linear(256→128) ReLU Dropout
  →  Linear(128→N)  →  softmax  →  class + confidence
```

**14 Features per frame** (joint angles + spatial positions):
- Knee, elbow, hip, shoulder angles (L+R, normalised to [0,1])
- Arm spread, hip spread, torso inclination
- Wrist position relative to hip

**Physics validation** — after BiLSTM prediction, exercise-specific motion constraints are checked. If they fail (e.g. low knee ROM claimed as jumping jack), the system falls back to the rule-based classifier.

**Training:**
```bash
# Synthetic data (default, no recordings needed)
cd backend
python -m app.analysis.train_bilstm

# Mixed (recommended when you have real video clips)
python -m app.analysis.train_bilstm --mode mixed --real-data-dir data/real/sequences

# Evaluate
python -m app.analysis.evaluate_bilstm
```

To add a new exercise: place video clips in `data/real/videos/<exercise_name>/`, reprocess, retrain. The class list is embedded in the weights file — no code changes required.

---

### 5.4 LLM Coaching (Ollama)

All LLM calls go through `app/feedback/llm.py` using the `ollama` Python client pointed at a local Ollama instance (default: `http://localhost:11434`).

**Three LLM use cases:**

| Use case | Function | System prompt focus |
|----------|----------|---------------------|
| Post-workout feedback | `generate_feedback()` | Professional fitness coach, concise, encouraging |
| Voice/chat queries | `answer_query()` | Session-aware Q&A, specific answers |
| Plan generation | `_generate_plan_llm()` | JSON-only structured workout plan |

Plan generation returns structured JSON matching the `WorkoutPlan` schema. Markdown code fences are stripped if present. If parsing fails, `_fallback_plan()` generates a profile-aware template.

---

### 5.5 Voice Assistant (STT / TTS)

`POST /api/v1/sessions/{id}/voice` handles both text and audio input:

```
audio_b64 (base64 WAV)  →  Whisper STT  →  query_text
                                              │
query_text  ─────────────────────────────────┤
                                              ▼
                                    Ollama answer_query()
                                              │
                                              ▼
                                    pyttsx3 TTS  →  audio_b64 (WAV)
```

Whisper runs locally (`base` model, ~74 MB). pyttsx3 uses the OS speech engine — no network calls. The voice query and response are persisted and shown in the session detail Q&A history.

---

### 5.6 Progress Tracking API

`/api/v1/progress/` — all endpoints require auth, all scoped to the current user.

| Endpoint | Returns |
|----------|---------|
| `GET /progress/summary` | Total sessions, reps, avg form score, sessions this week |
| `GET /progress/form-trend` | Array of `{date, avg_score}` per session (last 30) |
| `GET /progress/exercise-stats` | Per exercise: total reps, avg form, correct-rep % |
| `GET /progress/weight` | Full weight log history (chronological) |
| `POST /progress/weight` | Log a new weight entry `{weight_kg}` |

---

### 5.7 Workout Plans API

`/api/v1/plans/` — LLM-generated and user-managed.

| Endpoint | Description |
|----------|-------------|
| `POST /plans/generate` | Reads user profile → LLM → creates plan in DB |
| `GET  /plans` | List all plans for current user |
| `GET  /plans/{id}` | Full plan with all exercises |
| `PATCH /plans/{id}/exercises/{ex_id}/toggle` | Mark exercise complete / incomplete |
| `DELETE /plans/{id}` | Delete plan |

Plan exercises have `day_of_week` (0=Mon … 6=Sun), `sets_target`, `reps_target`, `duration_target_s`, and `completed_at`.

---

### 5.8 Database Layer

Async SQLAlchemy 2.0 with **PostgreSQL 16** via `asyncpg`. All operations go through `app/db/crud.py`. Schema changes are managed by Alembic migrations.

```bash
# Apply all migrations
cd backend && alembic upgrade head

# Create a new migration
alembic revision --autogenerate -m "description"
```

---

## 6. Database Schema

```
users
  id · email · hashed_password · created_at
  └──< profiles
        user_id · primary_goal · fitness_level · equipment
        activity_level · weekly_workout_target · injuries · weight_kg

users
  └──< sessions
        id · user_id · created_at · status · duration_s
        │
        └──< exercise_sets
        │     id · session_id · exercise_type · rep_count · correct_reps
        │     duration_s · form_score · rep_scores (JSON [float])
        │     └──< posture_errors
        │           id · exercise_set_id · error_type · occurrences · severity
        │
        ├──< ai_feedback
        │     id · session_id · feedback_text · generated_at
        │
        └──< voice_queries
              id · session_id · query_text · response_text · created_at

users
  ├──< weight_logs
  │     id · user_id · weight_kg · logged_at
  │
  └──< workout_plans
        id · user_id · title · description · duration_weeks · created_at
        └──< plan_exercises
              id · plan_id · day_of_week · exercise_type
              sets_target · reps_target · duration_target_s · notes · completed_at
```

All cascade deletes are set at both the SQLAlchemy relationship level (`cascade="all, delete-orphan"`) and the DB level (`ON DELETE CASCADE`).

---

## 7. Flutter App Deep Dive

Single Dart codebase targeting **iOS, Android, and Web**. The web build is served by Nginx as a SPA (single-page app).

### 7.1 Navigation & Shell

**GoRouter** handles all routing with an auth redirect guard:
- Unauthenticated → redirects to `/login`
- Authenticated on `/login` → redirects to `/`

A **ShellRoute** wraps all authenticated screens with `AppShell`, which adapts the layout:
- **≥ 768 px (web/tablet):** 240px collapsible sidebar (`SideNav`)
- **< 768 px (mobile):** content + bottom navigation bar (`BottomNav`)

**Routes:**

| Path | Screen |
|------|--------|
| `/login` | LoginScreen |
| `/` | HomeScreen |
| `/analyze` | AnalyzeScreen |
| `/history` | HistoryScreen |
| `/sessions/:id` | SessionDetailScreen |
| `/progress` | ProgressScreen |
| `/plans` | PlansScreen |
| `/plans/:id` | PlanDetailScreen |
| `/library` | LibraryScreen |
| `/assistant` | AssistantScreen |
| `/settings` | SettingsScreen |
| `/profile/edit` | EditProfileScreen |

---

### 7.2 Screens

**HomeScreen** — KPI cards (sessions this week, total reps, avg form), last 3 session cards with form score ring, quick upload shortcut.

**AnalyzeScreen** — Platform-adaptive picker (camera on mobile, file picker on web), upload with progress steps (Uploading → Processing → Analyzing → Generating feedback), polls every 2s, shows full result on completion.

**HistoryScreen** — Paginated session list with form score bar, swipe-to-delete with confirmation bottom sheet.

**SessionDetailScreen** — Date/time header, stat cards (reps / form score / duration), expandable `ExerciseCard` per set (rep chart + posture errors), AI coaching panel, Q&A history, share button.

**ProgressScreen** — Summary KPIs, weight log input + line chart (fl_chart), form score trend line chart, exercise stat rows with dual progress bars (form score + correct-rep accuracy).

**PlansScreen** — List of generated plans with week count and exercise count, "Generate AI Plan" action button. Tapping a plan opens `PlanDetailScreen`.

**PlanDetailScreen** — Day-by-day schedule (Mon–Sun). Each exercise row shows sets × reps target and taps to toggle completion (animated circle checkbox). Progress bar shows week completion %.

**LibraryScreen** — Category filter chips (All / Legs / Arms / Cardio / Core), expandable exercise cards showing description, muscles, form cues (green), and common mistakes (red).

**AssistantScreen** — Session selector, chat bubbles (user right / AI left), text input + send, voice recording button, suggested question chips, audio playback for TTS responses.

---

### 7.3 State Management

All state managed with **Riverpod** (`flutter_riverpod`).

| Provider type | Used for |
|---------------|----------|
| `FutureProvider` | Single async data fetch (session, plan, progress summary) |
| `FutureProvider.family` | Parameterised async fetch (session by ID, plan by ID) |
| `StateNotifierProvider` | Mutable state with actions (auth, analyze, voice recording, plan generation, weight logging) |
| `StateProvider` | Simple toggle state (sidebar expanded, theme mode) |

Providers are invalidated after mutations to trigger re-fetch:
```dart
ref.invalidate(plansProvider);          // after generate / delete
ref.invalidate(weightHistoryProvider);  // after log weight
ref.invalidate(sessionResultProvider(id)); // after delete
```

---

### 7.4 API Client

`core/api/client.dart` — Dio singleton configured with:
- Base URL from `flutter_secure_storage` (user-configurable in Settings)
- `Authorization: Bearer <token>` interceptor (reads token from secure storage)
- 30s connection timeout

`core/api/api_service.dart` — Typed wrapper methods for every backend endpoint. Returns Dart model objects (never raw JSON in the UI layer).

Token and server URL are stored in `flutter_secure_storage` — encrypted on-device, survives app restarts.

---

### 7.5 Design System

Defined in `design-system/MASTER.md`, implemented in `core/theme/app_theme.dart`.

**Dark theme (default):**

| Token | Color | Usage |
|-------|-------|-------|
| Background | `#0A0A0F` | Scaffold background |
| Surface | `#111118` | Cards, nav |
| Primary | `#6366F1` | CTAs, active nav, charts |
| Health / Success | `#10B981` | Good form, rep quality ≥ 80% |
| Warning | `#F59E0B` | Moderate form (50–79%) |
| Error | `#EF4444` | Poor form (< 50%), high severity errors |
| Text primary | `#F1F5F9` | Body text |
| Text muted | `#94A3B8` | Labels, secondary text |
| Border | `rgba(255,255,255,0.07)` | Card borders, dividers |
| Font | Inter (Google Fonts) | All text |

Both `AppTheme.dark` and `AppTheme.light` are defined; the active theme is persisted and toggled from Settings.

---

## 8. Full Request Flows

### Video Analysis (async polling)

```
Flutter AnalyzeScreen
  │  POST /sessions/analyze  (multipart video)
  ▼
FastAPI → create DB row (status=processing) → start BackgroundTask → return {id, status}
  │
  └─ BackgroundTask:
       CV Pipeline → BiLSTM classify → Rule analyser → Aggregate
       → Ollama feedback → save all to DB → status=completed

Flutter (polls every 2s)
  │  GET /sessions/{id}
  ▼
  status=processing  →  keep polling
  status=completed   →  cancel timer, show results
```

### AI Plan Generation

```
Flutter PlansScreen  →  tap "Generate AI Plan"
  │  POST /plans/generate
  ▼
FastAPI → load user profile from DB
  │
  └─ Ollama prompt:
       System: JSON-only workout plan format
       User: profile (goal, level, equipment, injuries, target days/week)
       → parse JSON response (strip markdown fences)
       → fallback to template if parse fails
  │
  └─ Save plan + exercises to DB → return serialized plan

Flutter → invalidate plansProvider → list refreshes with new plan
```

### Voice Query

```
Flutter AssistantScreen  →  record audio  →  base64 encode
  │  POST /sessions/{id}/voice  {audio_b64: "..."}
  ▼
FastAPI
  ├─ Whisper STT: base64 WAV → transcript text
  ├─ Load session context from DB
  ├─ Ollama: answer_query(transcript, session_context) → response_text
  ├─ pyttsx3 TTS: response_text → WAV bytes → base64
  ├─ Save VoiceQuery row
  └─ Return {query_text, response_text, audio_b64}

Flutter → append to conversation list → play audio response
```

---

## 9. Environment & Configuration

### Backend

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | — | PostgreSQL async URL (`postgresql+asyncpg://...`) |
| `SECRET_KEY` | — | JWT signing key (required in production) |
| `OLLAMA_HOST` | `http://localhost:11434` | Ollama server URL |
| `OLLAMA_MODEL` | `llama3.2` | Model for all LLM calls |
| `ALLOWED_ORIGINS` | `http://localhost` | CORS allowed origins |
| `ANALYZE_RATE_LIMIT` | `10/minute` | Rate limit per IP for `/analyze` |

### Flutter App

The server URL is stored in device secure storage and set from the Settings screen — no build-time env vars needed. Default is `http://localhost:8000` (overridden in Docker to the Nginx proxy URL).

---

## 10. Docker Setup

### Development

```bash
# Copy .env.example and fill in GROQ_API_KEY (get one free at console.groq.com)
cp .env.example .env
docker-compose -f docker-compose.dev.yml up
```

- Backend mounted as volume with `--reload` (hot reload on file changes)
- PostgreSQL with persistent volume
- LLM inference via Groq API (set `GROQ_API_KEY` in `.env`)

Run migrations after first start:
```bash
docker exec phva-backend-dev alembic upgrade head
```

Flutter app runs locally (not containerized in dev):
```bash
cd app
flutter pub get
flutter run -d chrome       # web
flutter run -d ios          # iOS simulator
flutter run -d android      # Android emulator
```

### Production (self-hosted)

```bash
# Requires .env with POSTGRES_PASSWORD, SECRET_KEY, GROQ_API_KEY
docker-compose up --build
docker exec phva-backend alembic upgrade head
```

---

## 11. Deployment — Railway + Groq

### Architecture

```
Flutter Web  (Railway Service 2)
     │  HTTPS  https://phva-web.railway.app
     │
     ▼
FastAPI      (Railway Service 1)   ←→  Groq API (LLM)
     │  postgresql://
     ▼
PostgreSQL   (Railway Addon — same service as backend)
```

### Step 1 — Get a free Groq API key

1. Go to [console.groq.com](https://console.groq.com) → Sign up (free)
2. **API Keys** → **Create API Key** → copy it (`gsk_...`)

### Step 2 — Deploy the Backend to Railway

1. Go to [railway.app](https://railway.app) → **New Project** → **Deploy from GitHub repo**
2. Select this repository
3. Railway auto-detects `railway.toml` at the root and uses `backend/Dockerfile`
4. Click **Add Plugin** → **PostgreSQL** — Railway injects `DATABASE_URL` automatically
5. Go to **Variables** and add:

   | Variable | Value |
   |----------|-------|
   | `SECRET_KEY` | any random 32-char string |
   | `GROQ_API_KEY` | `gsk_...` from Step 1 |
   | `ALLOWED_ORIGINS` | `https://<your-web-service>.railway.app` (add after Step 3) |

6. Deploy — Railway builds and runs the backend
7. Copy your backend URL, e.g. `https://phva-backend-production.railway.app`
8. In the Railway shell (or via CLI): `railway run alembic upgrade head`

### Step 3 — Deploy the Flutter Web App to Railway

1. In the same Railway project, click **New Service** → **GitHub repo** (same repo)
2. Set **Root Directory** to `/app`
3. Railway picks up `app/railway.toml` and uses `app/Dockerfile`
4. Go to **Variables** and add:

   | Variable | Value |
   |----------|-------|
   | `API_BASE` | `https://phva-backend-production.railway.app/api/v1` |

5. Deploy — Railway builds Flutter web (~10 min first build) and serves it via nginx
6. Go back to the backend service → Variables → update `ALLOWED_ORIGINS` to this web service URL

### Step 4 — Mobile App

No server needed for the Flutter mobile app. Set the backend URL in the app:

- iOS/Android: **Settings → Backend Server URL** → enter `https://phva-backend-production.railway.app`

### Cost estimate

| Service | Free tier |
|---------|-----------|
| Railway Backend | ~$0–2/month (within $5 free credit) |
| Railway Postgres | Included in $5 credit |
| Railway Flutter Web | ~$0–2/month (within $5 credit) |
| Groq LLM | Free tier: 14,400 requests/day |
| **Total** | **$0/month** for low traffic |

---

## 12. Development Commands

### Backend

```bash
cd backend

# Install dependencies
pip install -r requirements.txt

# Run dev server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Migrations
alembic upgrade head
alembic revision --autogenerate -m "description"

# Tests (72 passed, 1 xfailed)
pip install -r requirements-dev.txt
python -m pytest tests/ -v
python -m pytest tests/ --cov=app/analysis --cov-report=term-missing

# Train BiLSTM
python -m app.analysis.train_bilstm                           # synthetic
python -m app.analysis.train_bilstm --mode mixed              # real + synthetic
python -m app.analysis.evaluate_bilstm                        # eval report
```

### Flutter

```bash
cd app

flutter pub get                    # install packages
flutter run -d chrome              # web (dev)
flutter run -d ios                 # iOS simulator
flutter run -d android             # Android emulator
flutter build web --release        # production web build
flutter analyze                    # lint
```

---

## 12. Design Decisions

### PostgreSQL over SQLite
Multi-user support (subscription model) requires concurrent writes, proper row-level locking, and JSON column support for `rep_scores`. PostgreSQL handles all of this natively. Alembic manages schema evolution.

### Flutter over separate web/mobile codebases
Single Dart codebase targets iOS, Android, and web. No duplicated logic, one design system, one state management pattern. The adaptive shell (sidebar vs bottom nav) handles layout differences.

### Local-first LLM (Ollama)
All AI processing — coaching feedback, plan generation, voice queries — runs on a local Ollama instance. No data leaves the user's machine, no API keys, no per-call cost. This is a key differentiator for privacy-sensitive healthcare and fitness use cases.

### BiLSTM over pure rule-based classification
Rule-based classification works well for known exercises but can't be extended without new code. The BiLSTM embeds the class list in the weights file — adding a new exercise requires only recording video clips and retraining, no code changes. Dynamic class discovery enables the subscription model to offer exercise-specific tiers.

### Async video analysis with polling
MediaPipe + BiLSTM + Ollama can take 5–30 seconds. Running synchronously would block the HTTP connection and hit proxy timeouts. The background task pattern (`BackgroundTasks` in FastAPI) returns immediately with a processing ID and lets the client poll — better UX and compatible with any timeout-sensitive reverse proxy.

### Rate limiting on `/analyze`
The analysis endpoint is CPU/GPU intensive. `slowapi` rate limiting (10 req/min per IP by default, configurable) prevents abuse while keeping the API open for normal use. This is essential for the subscription model — free-tier limits can be enforced here.

### Per-rep scores in the database
`rep_scores` is stored as a JSON array on `exercise_sets`, not as individual rows. The array is small (≤ 30 floats typically), queried always alongside its parent row, and never filtered individually — a JSON column is simpler and faster than a separate `rep_score_items` table.
