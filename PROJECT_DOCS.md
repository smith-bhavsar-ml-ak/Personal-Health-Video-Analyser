# Personal Health Video Analyzer — Project Documentation

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [High-Level Architecture](#2-high-level-architecture)
3. [Repository Structure](#3-repository-structure)
4. [Backend Deep Dive](#4-backend-deep-dive)
   - 4.1 [Entry Point & App Bootstrap](#41-entry-point--app-bootstrap)
   - 4.2 [API Layer](#42-api-layer)
   - 4.3 [CV Pipeline](#43-cv-pipeline)
   - 4.4 [Exercise Analysis](#44-exercise-analysis)
   - 4.5 [LLM Feedback](#45-llm-feedback)
   - 4.6 [Voice (STT / TTS)](#46-voice-stt--tts)
   - 4.7 [Database Layer](#47-database-layer)
5. [Database Design](#5-database-design)
6. [Full Request Flow — Video Analysis](#6-full-request-flow--video-analysis)
7. [Frontend Deep Dive](#7-frontend-deep-dive)
   - 7.1 [Pages](#71-pages)
   - 7.2 [Components](#72-components)
   - 7.3 [API Client & Types](#73-api-client--types)
   - 7.4 [Theme System](#74-theme-system)
8. [Environment & Configuration](#8-environment--configuration)
9. [Docker Setup](#9-docker-setup)
10. [Key Design Decisions](#10-key-design-decisions)

---

## 1. Project Overview

**Personal Health Video Analyzer (PHVA)** is a full-stack web application that allows users to upload workout videos and receive AI-powered coaching feedback. The system:

- Extracts frames from the uploaded video
- Detects human body pose landmarks using **MediaPipe**
- Classifies exercises and counts reps using rule-based biomechanical analysis
- Scores exercise form (0–100)
- Sends structured workout data to a **local Ollama LLM** (llama3.2) for natural-language coaching feedback
- Lets users query their session via text or voice (Whisper STT + pyttsx3 TTS)
- Persists everything in a local **SQLite** database
- Displays results on a **Next.js 14** dashboard

---

## 2. High-Level Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                        Browser (Next.js 14)                    │
│  Dashboard · Analyze · History · AI Coach · Session Detail     │
└─────────────────────────────┬──────────────────────────────────┘
                              │  HTTP (REST JSON / multipart)
                              ▼
┌────────────────────────────────────────────────────────────────┐
│                    FastAPI  (port 8000)                        │
│                                                                │
│  POST /api/v1/sessions/analyze                                 │
│  GET  /api/v1/sessions                                         │
│  GET  /api/v1/sessions/{id}                                    │
│  DELETE /api/v1/sessions/{id}                                  │
│  POST /api/v1/sessions/{id}/voice                              │
│  GET  /api/v1/health                                           │
└──────┬──────────────────────┬───────────────────┬─────────────┘
       │                      │                   │
       ▼                      ▼                   ▼
┌─────────────┐   ┌───────────────────┐  ┌──────────────────┐
│  CV Pipeline│   │  Ollama (llama3.2)│  │  SQLite Database │
│             │   │  port 11434       │  │  /app/data/phva.db│
│  OpenCV     │   │  (runs on host)   │  │                  │
│  MediaPipe  │   └───────────────────┘  │  sessions        │
│  Rule-based │                          │  exercise_sets   │
│  Analyzers  │   ┌───────────────────┐  │  posture_errors  │
│             │   │  Voice            │  │  ai_feedback     │
└─────────────┘   │  Whisper STT      │  │  voice_queries   │
                  │  pyttsx3 TTS      │  └──────────────────┘
                  └───────────────────┘
```

---

## 3. Repository Structure

```
Personal Health Video Analyzer/
│
├── backend/                        # Python/FastAPI service
│   ├── app/
│   │   ├── main.py                 # FastAPI app, CORS, DB init
│   │   ├── api/
│   │   │   ├── sessions.py         # /sessions routes (analyze, list, get, delete)
│   │   │   └── voice.py            # /voice route (STT/TTS queries)
│   │   ├── cv/
│   │   │   ├── frame_extractor.py  # OpenCV: video → sampled frames
│   │   │   ├── pose_detector.py    # MediaPipe: frames → landmark arrays
│   │   │   └── pipeline.py         # Orchestrates extractor + detector
│   │   ├── analysis/
│   │   │   ├── base.py             # Abstract ExerciseAnalyser class
│   │   │   ├── rule_based.py       # Dispatcher: routes frames to correct analyser
│   │   │   ├── aggregator.py       # Merges per-exercise results into session summary
│   │   │   └── exercises/
│   │   │       ├── squat.py
│   │   │       ├── jumping_jack.py
│   │   │       ├── bicep_curl.py
│   │   │       ├── lunge.py
│   │   │       └── plank.py
│   │   ├── feedback/
│   │   │   └── llm.py              # Ollama client, prompt building, response parsing
│   │   ├── voice/
│   │   │   ├── stt.py              # Whisper transcription (audio → text)
│   │   │   └── tts.py              # pyttsx3 synthesis (text → audio base64)
│   │   └── db/
│   │       ├── database.py         # Async SQLAlchemy engine + session factory
│   │       ├── models.py           # ORM table definitions
│   │       └── crud.py             # All DB read/write operations
│   ├── requirements.txt
│   └── Dockerfile
│
├── frontend/                       # Next.js 14 / TypeScript
│   └── src/
│       ├── app/
│       │   ├── layout.tsx          # Root layout: sidebar + header + ThemeProvider
│       │   ├── globals.css         # CSS variables (dark/light theme tokens)
│       │   ├── page.tsx            # Dashboard (client component, fetches on mount)
│       │   ├── analyze/page.tsx    # Video upload + analysis results
│       │   ├── history/page.tsx    # Session list with delete
│       │   ├── assistant/page.tsx  # AI Coach chat + session picker
│       │   └── session/[id]/page.tsx # Session detail view
│       ├── components/
│       │   ├── layout/
│       │   │   ├── Sidebar.tsx     # Navigation + Settings modal (theme toggle)
│       │   │   └── Header.tsx      # Page title bar
│       │   ├── dashboard/
│       │   │   ├── StatCard.tsx
│       │   │   ├── FormTrendChart.tsx
│       │   │   ├── ExerciseBreakdown.tsx
│       │   │   ├── RecentSessions.tsx
│       │   │   └── QuickUpload.tsx
│       │   ├── analyze/
│       │   │   ├── VideoUploader.tsx
│       │   │   ├── AnalysisProgress.tsx
│       │   │   ├── ExerciseCard.tsx
│       │   │   ├── RepChart.tsx
│       │   │   ├── PostureErrorList.tsx
│       │   │   └── AIFeedbackPanel.tsx
│       │   └── assistant/
│       │       ├── MessageBubble.tsx
│       │       └── SuggestionChips.tsx
│       ├── contexts/
│       │   └── ThemeContext.tsx    # Dark/light theme state + localStorage
│       └── lib/
│           ├── api.ts              # Typed fetch wrapper for all backend calls
│           └── types.ts            # Shared TypeScript interfaces
│
├── scripts/
│   └── start-ollama.ps1            # Cross-platform Ollama start script (pwsh)
├── docker-compose.yml              # Production stack
├── docker-compose.dev.yml          # Dev stack (hot reload)
├── Makefile                        # Developer shortcuts
└── PROJECT_DOCS.md                 # This file
```

---

## 4. Backend Deep Dive

### 4.1 Entry Point & App Bootstrap

**`app/main.py`**

```
FastAPI()
  ├── CORS middleware  →  allow origins: ["http://localhost:3000"]
  ├── @app.on_event("startup")  →  init_db()   (creates tables if missing)
  ├── include_router(sessions_router, prefix="/api/v1")
  ├── include_router(voice_router,    prefix="/api/v1")
  └── GET /api/v1/health  →  {"status": "ok"}
```

On startup, `init_db()` (in `db/database.py`) calls `Base.metadata.create_all()` asynchronously, which creates the SQLite file and all tables if they don't already exist. No migrations are needed for development.

---

### 4.2 API Layer

#### `app/api/sessions.py` — 5 endpoints

| Method | Path | What it does |
|--------|------|--------------|
| `POST` | `/sessions/analyze` | Accepts multipart video file, runs full pipeline, returns `SessionResult` |
| `GET` | `/sessions` | Returns list of `SessionSummary` objects (all sessions, newest first) |
| `GET` | `/sessions/{id}` | Returns full `SessionResult` including exercise sets, errors, feedback, voice queries |
| `DELETE` | `/sessions/{id}` | Hard-deletes session and all child rows (cascade) |

**`POST /sessions/analyze` — internal steps:**
```
1. Save uploaded file to /tmp
2. create_session() in DB  →  status = "processing"
3. run_pipeline(video_path)
     └── extract_frames()     (OpenCV)
     └── detect_poses()       (MediaPipe)
4. analyse_exercises(pose_frames)
     └── RuleBasedAnalyser.dispatch()
     └── Each exercise analyser runs independently
5. build_feedback_context(results)
6. generate_feedback(context)   →  Ollama llama3.2
7. save_results() to DB         →  status = "completed"
8. Return full SessionResult JSON
```

#### `app/api/voice.py`

`POST /sessions/{id}/voice` accepts either:
- `query_text` (string) — already transcribed
- `audio_b64` (base64 WAV) — transcribed via Whisper first

Then calls `answer_query(text, session_context)` on the LLM and optionally synthesizes the response to audio via pyttsx3.

---

### 4.3 CV Pipeline

#### `app/cv/frame_extractor.py`

Uses **OpenCV** (`cv2.VideoCapture`) to open the video file and extract frames at a configurable interval (default: every Nth frame based on video FPS to target ~10 fps worth of pose data). Returns a list of numpy arrays (BGR images).

```python
def extract_frames(video_path: str, target_fps: int = 10) -> list[np.ndarray]:
    cap = cv2.VideoCapture(video_path)
    native_fps = cap.get(cv2.CAP_PROP_FPS)
    step = max(1, int(native_fps / target_fps))
    # reads every `step`-th frame, returns list of frames
```

#### `app/cv/pose_detector.py`

Uses **MediaPipe Pose** (`mp.solutions.pose`) to detect 33 body landmarks on each frame. Each landmark has `(x, y, z, visibility)` normalized to frame dimensions.

```python
class PoseDetector:
    def __init__(self):
        self.pose = mp.solutions.pose.Pose(
            static_image_mode=False,
            model_complexity=1,
            min_detection_confidence=0.5
        )

    def detect(self, frame: np.ndarray) -> PoseLandmarks | None:
        # converts BGR → RGB, runs MediaPipe, returns landmark dict
```

Key landmarks used by the analyzers:

| Landmark Index | Body Part |
|---------------|-----------|
| 11, 12 | Left/Right Shoulder |
| 13, 14 | Left/Right Elbow |
| 15, 16 | Left/Right Wrist |
| 23, 24 | Left/Right Hip |
| 25, 26 | Left/Right Knee |
| 27, 28 | Left/Right Ankle |

#### `app/cv/pipeline.py`

Thin orchestrator that chains the two CV steps:

```python
def run_pipeline(video_path: str) -> list[PoseFrame]:
    frames = extract_frames(video_path)
    return detect_poses(frames)   # list of {frame_idx, landmarks, timestamp_ms}
```

---

### 4.4 Exercise Analysis

#### `app/analysis/base.py` — Abstract Base

```python
class ExerciseAnalyser(ABC):
    @abstractmethod
    def analyse(self, pose_frames: list[PoseFrame]) -> ExerciseResult:
        """
        Takes a sequence of pose frames, returns:
        - exercise_type: str
        - rep_count: int
        - correct_reps: int
        - duration_s: float
        - form_score: float  (0–100)
        - posture_errors: list[PostureError]
        """
```

#### `app/analysis/rule_based.py` — Dispatcher

Detects which exercise is being performed by analysing the overall motion pattern across all frames (e.g., vertical vs. horizontal dominant movement, arm position relative to body), then delegates to the matching analyser.

```python
class RuleBasedAnalyser:
    _registry = {
        "squat":        SquatAnalyser,
        "jumping_jack": JumpingJackAnalyser,
        "bicep_curl":   BicepCurlAnalyser,
        "lunge":        LungeAnalyser,
        "plank":        PlankAnalyser,
    }

    def dispatch(self, pose_frames) -> list[ExerciseResult]:
        exercise_type = self._classify(pose_frames)
        analyser = self._registry[exercise_type]()
        return [analyser.analyse(pose_frames)]
```

#### `app/analysis/exercises/` — Individual Analyzers

Each analyser implements the same interface but with exercise-specific logic:

**`squat.py`**
- Tracks **knee angle** (hip → knee → ankle) over time
- Rep counted when angle drops below threshold (flexion) then returns above (extension)
- Form errors: `back_lean` (hip-to-shoulder angle), `knee_cave` (knee x vs ankle x), `shallow_squat` (insufficient depth)

**`jumping_jack.py`**
- Tracks **arm abduction** (wrist distance normalized to shoulder width) and **leg spread** (ankle distance normalized to hip width)
- Rep counted on open → close cycle
- Form errors: `arm_height` (wrists not above shoulders at top), `incomplete_spread` (legs not wide enough)

**`bicep_curl.py`**
- Tracks **elbow angle** (shoulder → elbow → wrist)
- Rep counted on full extension → full flexion → extension cycle
- Form errors: `shoulder_sway` (shoulder moves during curl), `incomplete_extension`, `incomplete_flexion`

**`lunge.py`**
- Detects forward step by tracking difference in knee heights and hip drop
- Rep counted per alternating leg lunge
- Form errors: `forward_lean`, `knee_over_toe` (front knee x past front ankle x)

**`plank.py`**
- No rep counting (isometric hold)
- Measures **body alignment**: shoulder → hip → ankle should form a straight line
- Form score based on deviation from straight line over time
- Form errors: `hip_sag`, `hip_pike`

#### `app/analysis/aggregator.py`

Merges results from multiple exercises (if present) into a single session summary:

```python
def aggregate(results: list[ExerciseResult]) -> SessionSummary:
    return SessionSummary(
        total_reps      = sum(r.rep_count for r in results),
        avg_form_score  = mean(r.form_score for r in results),
        duration_s      = sum(r.duration_s for r in results),
        exercise_types  = [r.exercise_type for r in results],
    )
```

---

### 4.5 LLM Feedback

**`app/feedback/llm.py`**

Uses the official `ollama` Python client to call a locally running Ollama server.

```python
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434")
MODEL       = os.getenv("OLLAMA_MODEL", "llama3.2")

SYSTEM_PROMPT = """You are a professional fitness coach AI.
Analyse workout data and provide clear, encouraging, and actionable coaching feedback.
Keep responses concise (2-4 sentences per exercise). Be specific about form issues.
Use simple, motivating language. Never be discouraging."""
```

**`generate_feedback(workout_context: str) → str`**
- Called after analysis with a structured text block like:
  ```
  Exercise: Squat
    Reps: 8 total, 8 correct form
    Form Score: 85/100
    Issues detected:
      - back lean: 290 times (high severity)
  ```
- Returns the LLM's coaching text (2–4 sentences)
- Typical response time: 2–5 seconds with llama3.2

**`answer_query(query: str, session_context: str) → str`**
- Used by the voice/chat endpoint
- Includes full session data as context so the LLM can answer specific questions

---

### 4.6 Voice (STT / TTS)

**`app/voice/stt.py`** — Speech-to-Text

Uses **OpenAI Whisper** (runs locally, no API key needed):

```python
import whisper
model = whisper.load_model("base")  # ~74MB, loaded once on import

def transcribe(audio_b64: str) -> str:
    # decode base64 → temp WAV file → whisper.transcribe() → text
```

**`app/voice/tts.py`** — Text-to-Speech

Uses **pyttsx3** (offline TTS engine):

```python
import pyttsx3

def synthesize(text: str) -> str | None:
    # renders text to a temp WAV file → reads bytes → returns base64
    # returns None if synthesis fails (non-critical)
```

---

### 4.7 Database Layer

**`app/db/database.py`** — Engine Setup

```python
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite+aiosqlite:///./data/phva.db")

engine = create_async_engine(DATABASE_URL, echo=False)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)

async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

async def get_db() -> AsyncGenerator:
    async with AsyncSessionLocal() as session:
        yield session
```

The `get_db` function is used as a FastAPI dependency injection — every request gets its own DB session that is automatically closed when the request completes.

**`app/db/crud.py`** — All database operations

| Function | Description |
|----------|-------------|
| `create_session()` | Inserts new row, returns session UUID |
| `update_session_status()` | Sets status to completed/failed |
| `save_exercise_set()` | Saves rep/score data for one exercise |
| `save_posture_errors()` | Bulk-saves error rows linked to exercise_set |
| `save_ai_feedback()` | Saves LLM coaching text |
| `save_voice_query()` | Saves user query + LLM response |
| `list_sessions()` | Returns all sessions newest-first, with aggregate fields |
| `get_session()` | Returns full session with all related rows (joined) |
| `delete_session()` | Cascading delete of session + all children |

---

## 5. Database Design

The database is a single **SQLite** file at `/app/data/phva.db` (mounted as a Docker volume for persistence). All tables use **UUID strings** as primary keys.

### Entity Relationship Diagram

```
sessions
  │   id (PK, UUID)
  │   created_at
  │   status           "processing" | "completed" | "failed"
  │   duration_s
  │
  ├──< exercise_sets
  │       id (PK, UUID)
  │       session_id (FK → sessions.id)
  │       exercise_type    "squat" | "jumping_jack" | "bicep_curl" | "lunge" | "plank"
  │       rep_count
  │       correct_reps
  │       duration_s
  │       form_score       0.0 – 100.0
  │
  │       └──< posture_errors
  │               id (PK, UUID)
  │               exercise_set_id (FK → exercise_sets.id)
  │               error_type       e.g. "back_lean", "knee_cave"
  │               occurrences      how many frames this error appeared
  │               severity         "low" | "medium" | "high"
  │
  ├──< ai_feedback
  │       id (PK, UUID)
  │       session_id (FK → sessions.id)   ← one feedback per session
  │       feedback_text
  │       generated_at
  │
  └──< voice_queries
          id (PK, UUID)
          session_id (FK → sessions.id)
          query_text
          response_text
          created_at
```

### SQLAlchemy Models (`app/db/models.py`)

```python
class Session(Base):
    __tablename__ = "sessions"
    id          = Column(String, primary_key=True, default=lambda: str(uuid4()))
    created_at  = Column(DateTime, default=datetime.utcnow)
    status      = Column(String, default="processing")
    duration_s  = Column(Float, nullable=True)

    exercise_sets = relationship("ExerciseSet", back_populates="session",
                                 cascade="all, delete-orphan")
    ai_feedback   = relationship("AIFeedback",  back_populates="session",
                                 cascade="all, delete-orphan", uselist=False)
    voice_queries = relationship("VoiceQuery",  back_populates="session",
                                 cascade="all, delete-orphan")


class ExerciseSet(Base):
    __tablename__ = "exercise_sets"
    id              = Column(String, primary_key=True, default=lambda: str(uuid4()))
    session_id      = Column(String, ForeignKey("sessions.id"))
    exercise_type   = Column(String)
    rep_count       = Column(Integer)
    correct_reps    = Column(Integer)
    duration_s      = Column(Float)
    form_score      = Column(Float)

    posture_errors  = relationship("PostureError", back_populates="exercise_set",
                                   cascade="all, delete-orphan")


class PostureError(Base):
    __tablename__ = "posture_errors"
    id              = Column(String, primary_key=True, default=lambda: str(uuid4()))
    exercise_set_id = Column(String, ForeignKey("exercise_sets.id"))
    error_type      = Column(String)
    occurrences     = Column(Integer)
    severity        = Column(String)


class AIFeedback(Base):
    __tablename__ = "ai_feedback"
    id            = Column(String, primary_key=True, default=lambda: str(uuid4()))
    session_id    = Column(String, ForeignKey("sessions.id"))
    feedback_text = Column(Text)
    generated_at  = Column(DateTime, default=datetime.utcnow)


class VoiceQuery(Base):
    __tablename__ = "voice_queries"
    id            = Column(String, primary_key=True, default=lambda: str(uuid4()))
    session_id    = Column(String, ForeignKey("sessions.id"))
    query_text    = Column(Text)
    response_text = Column(Text)
    created_at    = Column(DateTime, default=datetime.utcnow)
```

### Cascade Delete

All child tables use `cascade="all, delete-orphan"` in SQLAlchemy and `ON DELETE CASCADE` at the DB level. Deleting a `Session` row automatically removes all linked `exercise_sets`, `posture_errors`, `ai_feedback`, and `voice_queries`.

---

## 6. Full Request Flow — Video Analysis

This is the most important flow in the system. Here is the complete path for `POST /api/v1/sessions/analyze`:

```
Browser
  │
  │  multipart/form-data  video=<file>
  ▼
FastAPI  sessions.py::analyze_video()
  │
  ├─ 1. Save video to temp file  (/tmp/<uuid>.mp4)
  │
  ├─ 2. DB: create_session()
  │       sessions.status = "processing"
  │
  ├─ 3. CV: run_pipeline(video_path)
  │       ├─ frame_extractor.extract_frames()
  │       │     OpenCV reads video, samples every Nth frame
  │       │     Returns: list[np.ndarray]  (BGR images)
  │       │
  │       └─ pose_detector.detect_poses()
  │             MediaPipe Pose runs on each frame
  │             Returns: list[PoseFrame]
  │               {frame_idx, timestamp_ms, landmarks: {0..32: {x,y,z,vis}}}
  │
  ├─ 4. Analysis: RuleBasedAnalyser.dispatch(pose_frames)
  │       ├─ _classify(): examines motion patterns to ID exercise
  │       └─ ExerciseAnalyser.analyse(pose_frames)
  │             Counts reps via angle/position thresholds
  │             Scores form per rep
  │             Detects posture errors per frame
  │             Returns: ExerciseResult
  │               {exercise_type, rep_count, correct_reps,
  │                duration_s, form_score, posture_errors[]}
  │
  ├─ 5. Build feedback context (structured text summary)
  │
  ├─ 6. LLM: generate_feedback(context)
  │       Ollama client → POST http://host.docker.internal:11434/api/chat
  │       Model: llama3.2
  │       Returns: coaching text string
  │
  ├─ 7. DB: save all results
  │       save_exercise_set()    → exercise_sets row
  │       save_posture_errors()  → posture_errors rows (bulk)
  │       save_ai_feedback()     → ai_feedback row
  │       update_session_status("completed")
  │
  └─ 8. Return SessionResult JSON
          {id, created_at, status, exercise_sets[], ai_feedback, voice_queries[]}
```

---

## 7. Frontend Deep Dive

### 7.1 Pages

All pages live under `src/app/` following Next.js 14 App Router conventions.

| Page | File | Type | Description |
|------|------|------|-------------|
| Dashboard | `app/page.tsx` | Client | Stats, trend chart, exercise breakdown, recent sessions. Fetches on mount. |
| Analyze | `app/analyze/page.tsx` | Client | Upload zone → progress animation → results + AI feedback. Calls `router.refresh()` on completion. |
| History | `app/history/page.tsx` | Client | Sortable session list with delete (confirmation modal). Fetches on mount. |
| AI Coach | `app/assistant/page.tsx` | Client | Chat interface. Shows session picker when no session selected. Supports voice (WebAudio API → Whisper). |
| Session Detail | `app/session/[id]/page.tsx` | Server | Full session breakdown: per-exercise cards, posture errors, AI feedback, past voice queries. |

> **Why client components for Dashboard/History?**
> Next.js 14.x caches SSR pages in the router cache (~30s) even with `force-dynamic`. Converting to client components that fetch in `useEffect` bypasses this cache completely, ensuring always-fresh data on navigation.

### 7.2 Components

#### Layout
- **`Sidebar.tsx`** — Fixed 240px sidebar with nav links and a Settings button that opens a modal (theme toggle). Uses `useTheme()` hook.
- **`Header.tsx`** — Top bar showing current page title (derived from `usePathname()`).

#### Dashboard
- **`StatCard.tsx`** — Metric card with icon, label, value, optional delta indicator.
- **`FormTrendChart.tsx`** — Recharts `AreaChart` showing form score trend across last 10 sessions.
- **`ExerciseBreakdown.tsx`** — Recharts `RadialBarChart` showing proportion of each exercise type.
- **`RecentSessions.tsx`** — List of last 6 sessions with score badge and link to detail.
- **`QuickUpload.tsx`** — Shortcut card linking to `/analyze`.

#### Analyze
- **`VideoUploader.tsx`** — Drag-and-drop zone with file validation (`video/*` only).
- **`AnalysisProgress.tsx`** — 4-step progress indicator (Extracting → Detecting → Analysing → Generating feedback).
- **`ExerciseCard.tsx`** — Collapsible card showing rep count, form score, duration. Contains `RepChart` and `PostureErrorList`.
- **`RepChart.tsx`** — Bar chart of per-rep form scores (green/yellow/red by threshold).
- **`PostureErrorList.tsx`** — Error list with severity badges.
- **`AIFeedbackPanel.tsx`** — Displays LLM coaching text.

#### Assistant
- **`MessageBubble.tsx`** — Chat bubble (right-aligned for user, left for assistant). Includes audio player for TTS responses.
- **`SuggestionChips.tsx`** — 4 quick-start question buttons shown when session is loaded.

### 7.3 API Client & Types

**`src/lib/api.ts`**

Single typed fetch wrapper. Automatically switches base URL between:
- Server-side (SSR/RSC): `http://backend:8000` (Docker internal hostname)
- Client-side (browser): `http://localhost:8000`

```typescript
const BASE =
  typeof window === "undefined"
    ? (process.env.API_URL ?? "http://localhost:8000")
    : (process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000");

export const api = {
  analyzeVideo(file: File): Promise<SessionResult>
  listSessions(): Promise<SessionSummary[]>
  getSession(id: string): Promise<SessionResult>
  deleteSession(id: string): Promise<void>
  voiceQuery(sessionId: string, body: VoiceQueryRequest): Promise<VoiceQueryResponse>
}
```

**`src/lib/types.ts`**

All TypeScript interfaces that mirror the backend Pydantic schemas:

```typescript
ExerciseType = "squat" | "jumping_jack" | "bicep_curl" | "lunge" | "plank"

PostureError   { id, error_type, occurrences, severity }
ExerciseSet    { id, exercise_type, rep_count, correct_reps, duration_s, form_score, posture_errors[] }
AIFeedback     { feedback_text, generated_at }
VoiceQuery     { id, query_text, response_text, created_at }
SessionSummary { id, created_at, duration_s, status, total_reps, avg_form_score, exercise_types[] }
SessionResult  { id, created_at, duration_s, status, exercise_sets[], ai_feedback, voice_queries[] }
```

### 7.4 Theme System

The app supports **dark** (default) and **light** themes, persisted in `localStorage`.

**How it works:**

1. **CSS variables** in `globals.css` define two palettes on `:root` (dark) and `.light` (light):
   ```css
   :root { --color-bg: 10 10 15; --color-surface: 17 17 24; ... }
   .light { --color-bg: 243 244 246; --color-surface: 255 255 255; ... }
   ```

2. **Tailwind config** references these variables with `<alpha-value>` support:
   ```ts
   bg: "rgb(var(--color-bg) / <alpha-value>)"
   ```
   This means every Tailwind utility like `bg-surface-2/60` or `text-text-primary` responds to the active theme automatically.

3. **`ThemeContext`** (`src/contexts/ThemeContext.tsx`) reads `localStorage` on mount and toggles the `light` class on `<html>`.

4. **Anti-flash script** in `layout.tsx` runs synchronously before React hydration to apply the saved theme class before the first paint, preventing a flash of the wrong theme.

---

## 8. Environment & Configuration

### Backend Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_HOST` | `http://localhost:11434` | Ollama server URL |
| `OLLAMA_MODEL` | `llama3.2` | Model to use for feedback and queries |
| `DATABASE_URL` | `sqlite+aiosqlite:///./data/phva.db` | SQLAlchemy async DB URL |

### Frontend Environment Variables

| Variable | Used by | Description |
|----------|---------|-------------|
| `API_URL` | SSR (server-side) | Backend URL from inside Docker network |
| `NEXT_PUBLIC_API_URL` | Client-side (browser) | Backend URL accessible from browser |

In Docker Compose, `API_URL=http://backend:8000` (service name) and `NEXT_PUBLIC_API_URL=http://localhost:8000` (host-mapped port).

---

## 9. Docker Setup

### Production (`docker-compose.yml`)

```
services:
  backend   → builds ./backend, port 8000, mounts sqlite_data volume
  frontend  → builds ./frontend, port 3000
  (Ollama runs on host, accessed via host.docker.internal:11434)

volumes:
  sqlite_data  → persists /app/data/phva.db across container restarts
```

### Development (`docker-compose.dev.yml`)

Same services but with source code mounted as volumes + hot-reload commands:
- Backend: `uvicorn app.main:app --reload`
- Frontend: `npm run dev`

### Makefile shortcuts

```bash
make dev              # Start dev stack (also starts Ollama via pwsh script)
make up               # Start production stack
make down             # Stop all services
make logs             # Tail all logs
make logs-back        # Backend logs only
make health           # Check backend + Ollama status
make restart-backend  # Restart backend container only
make clean            # Remove containers and images
```

---

## 10. Key Design Decisions

### Why SQLite instead of PostgreSQL?
Single-user local app. SQLite requires zero setup, runs embedded in the backend container, and is sufficient for the data volume. The async driver (`aiosqlite`) keeps it non-blocking.

### Why Ollama instead of a cloud LLM API?
Privacy — workout data never leaves the machine. Ollama runs llama3.2 locally with no API key, no latency from external calls, and no cost.

### Why rule-based exercise analysis instead of an ML classifier?
MediaPipe already gives clean landmark coordinates. Computing joint angles from landmarks is deterministic, explainable, and fast. An ML classifier would need labelled training data and a model file. The rule-based approach gives identical accuracy for the supported exercise set with far less complexity.

### Why client-side data fetching for Dashboard and History?
Next.js 14's router cache caches pages for ~30s even with `force-dynamic`, causing stale data on client navigation. Client components fetching in `useEffect` bypass the router cache entirely — the data is always fresh on every page visit.

### Why UUID primary keys?
Avoids sequential ID enumeration in URLs and makes the system safe to expose (session IDs in the URL aren't guessable).
