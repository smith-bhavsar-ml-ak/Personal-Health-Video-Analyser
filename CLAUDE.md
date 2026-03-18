# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal Health Video Analyser — a full-stack web app that analyzes fitness exercise form via video. Users upload workout videos; the backend extracts frames, runs MediaPipe pose detection, classifies exercises, scores form, and generates LLM coaching feedback via a local Ollama instance.

## Architecture

```
Video Upload → CV Pipeline → Exercise Analysis → LLM Feedback → Database → Frontend Display
```

**Backend (Python/FastAPI)** at `backend/`
- `app/main.py` — FastAPI entry point, CORS, JSON structured logging, rate limiter, DB init on startup
- `app/api/` — Routes: `sessions.py` (analyze, list, get, delete), `voice.py` (STT/TTS queries)
- `app/core/limiter.py` — `slowapi` rate limiter (key: remote IP)
- `app/cv/` — Computer vision: `frame_extractor.py` → `pose_detector.py` → `pipeline.py`
  - `pipeline.py` exposes `run_cv_pipeline_from_bytes(content, filename)` — used by background tasks
- `app/analysis/` — Exercise analysis: `base.py` (abstract `ExerciseAnalyser`), `rule_based.py` (dispatcher), `exercises/` (squat, jumping_jack, bicep_curl, lunge, plank analyzers), `aggregator.py`
  - `bilstm_model.py` — PyTorch BiLSTM architecture; `CLASSES` kept as default fallback only
  - `bilstm_analyser.py` — Drop-in `run_analysis()` using BiLSTM + dict-based physics checks + graceful ANALYSERS fallback for dynamic classes
  - `features.py` — Extracts 14-dim float32 feature vector per PoseFrame
  - `train_bilstm.py` — Synthetic generators + augmentation + training loop; supports `--mode synthetic|real|mixed`
  - `preprocess_real_data.py` — Extracts labeled `.npy` sequences from real exercise videos
  - `evaluate_bilstm.py` — Standalone eval report: accuracy, noise robustness, speed
- `app/feedback/llm.py` — Ollama (llama3.2) integration for coaching feedback
- `app/voice/stt.py` — Whisper transcription; `voice/tts.py` — pyttsx3 TTS
- `app/db/` — Async SQLAlchemy with PostgreSQL (asyncpg): `models.py`, `crud.py`, `database.py`
- `alembic/` — Database migrations (async-compatible); run via `alembic upgrade head`

**Frontend (Next.js 14 / TypeScript)** at `frontend/`
- `src/app/` — App Router pages: `/` (dashboard), `/analyze`, `/history`, `/assistant`, `/session/[id]`
  - `analyze/page.tsx` — polls `getSession(id)` every 2s while `status === "processing"`
- `src/components/` — React components organized by page
- `src/lib/api.ts` — Typed fetch wrapper; `lib/types.ts` — shared TypeScript interfaces
  - `ExerciseType = string` (open type — backend drives the class list)
  - Use `getExerciseLabel(type)` / `getExerciseColor(type)` helpers for display; they handle unknown dynamic classes

**Infrastructure**
- **Nginx** — reverse proxy: `/api/` → `backend:8000`, `/` → `frontend:3000`; `client_max_body_size 200M`
- **PostgreSQL 16** — primary database (replaces SQLite)
- **Ollama** — must be running locally on port 11434

## Commands

### Backend
```bash
# Install
pip install -r backend/requirements.txt

# Run (dev with hot reload)
cd backend && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Run database migrations
cd backend && alembic upgrade head

# API docs
open http://localhost:8000/docs
```

### Frontend
```bash
cd frontend

npm install
npm run dev      # dev server on port 3000
npm run build    # production build
npm run lint     # ESLint
```

### Docker (recommended for full stack)
```bash
# Development (hot reload)
docker-compose -f docker-compose.dev.yml up

# Production (requires .env with POSTGRES_PASSWORD, SECRET_KEY)
docker-compose up
```

**Required env vars for production (`docker-compose.yml`):**
- `POSTGRES_PASSWORD` — PostgreSQL password (no default, fails loud)
- `SECRET_KEY` — app secret key (no default, fails loud)
- `OLLAMA_HOST` — Ollama URL (default: `http://host.docker.internal:11434`)
- `ALLOWED_ORIGINS` — CORS origins (default: `http://localhost`)
- `NEXT_PUBLIC_API_URL` — baked into frontend build (default: `http://localhost`)

## Design System

All UI changes must follow `design-system/MASTER.md`. Key rules:
- **Adaptive theming — never hardcode dark or light.** The Flutter app defaults to `ThemeMode.system` and respects user preference. Always use `Theme.of(context).colorScheme.*` for surfaces, borders, and text. Never use `AppColors.surface`, `AppColors.border`, `AppColors.surfaceElevated`, `AppColors.textPrimary`, `AppColors.textSecondary`, or `AppColors.textMuted` directly in widgets — these are dark-only values. Brand/semantic colors (`AppColors.primary`, `AppColors.health`, `AppColors.warning`, `AppColors.error`, `AppColors.info`) are identical in both themes and are safe to use directly.
  - `AppColors.surface` → `cs.surface`
  - `AppColors.surfaceElevated` → `cs.surfaceContainerHigh`
  - `AppColors.border` → `cs.outline`
  - `AppColors.textPrimary` → `cs.onSurface`
  - `AppColors.textSecondary` / `AppColors.textMuted` → `cs.onSurfaceVariant`
- **Primary:** Indigo `#6366F1`, health/success: Emerald `#10B981`, warnings: Amber, errors: Red
- **Layout:** 240px fixed sidebar; fluid main with `max-w-7xl`; mobile sidebar collapses to bottom tab bar
- **Icons:** Lucide React, 24×24, 1.5px stroke
- **Charts:** Recharts only
- **Anti-patterns:** No gradients, no emoji, no glassmorphism, border-radius max 16px on cards
- **Desktop card layout — MANDATORY:** Any screen that renders a list of cards MUST use `ResponsiveGrid` from `app/lib/widgets/responsive_grid.dart`. This widget renders 3 equal columns on screens ≥ 768 px and a single column on mobile. Never use `GridView`, hardcoded `Column`, or unconstrained `Row` for card lists — always wrap with `ResponsiveGrid`. This applies to all existing and future screens. Exceptions: full-bleed charts, single-item detail views, or explicitly single-column layout (e.g. a narrow form).

Page-specific design specs are in `design-system/pages/`.

## Key API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/sessions/analyze` | Upload video — returns immediately with `status="processing"` |
| GET | `/api/v1/sessions` | List all sessions |
| GET | `/api/v1/sessions/{id}` | Session details (poll until `status` is `completed` or `failed`) |
| DELETE | `/api/v1/sessions/{id}` | Delete session |
| POST | `/api/v1/sessions/{id}/voice` | Voice query on a session |
| GET | `/api/v1/health` | Health check |

**`/analyze` is rate-limited** (default: 10/minute per IP, configurable via `ANALYZE_RATE_LIMIT` env var).

**`/analyze` is async** — the heavy CV + ML work runs in a `BackgroundTask`. Poll `GET /sessions/{id}` until `status != "processing"`.

## BiLSTM Exercise Classifier

### Architecture

```
Input (batch, T, 14)
    │
    ▼
BiLSTM  — input=14, hidden=128, layers=2, bidirectional=True, dropout=0.3
    │       output: (batch, T, 256)  [256 = 128 × 2 directions]
    ▼
Mean-pool over time  →  (batch, 256)
    │
    ▼
Linear(256 → 128) → ReLU → Dropout(0.3)
    │
    ▼
Linear(128 → N)  →  logits  (N = number of classes, embedded in weights)
```

- **Default classes** (original 5): `squat`, `jumping_jack`, `bicep_curl`, `lunge`, `plank`
- **Dynamic classes**: class list is embedded in the weights checkpoint — adding new exercises requires only retraining, no code changes
- **Parameters**: ~576k (5 classes); scales with `num_classes`
- **Weights file**: `backend/app/analysis/weights/bilstm_classifier.pt`
- **Weights format**: `{'state_dict': ..., 'classes': [...]}` (backward-compat: plain state_dict still works)

### 14 Feature Vector (per frame)

| Index | Feature | Notes |
|-------|---------|-------|
| 0 | left_knee_angle / 180 | normalised to [0,1] |
| 1 | right_knee_angle / 180 | |
| 2 | left_elbow_angle / 180 | |
| 3 | right_elbow_angle / 180 | |
| 4 | left_hip_angle / 180 | |
| 5 | right_hip_angle / 180 | |
| 6 | left_shoulder_angle / 180 | |
| 7 | right_shoulder_angle / 180 | |
| 8 | arm_spread (wrist-to-wrist x-distance) | |
| 9 | hip_spread (hip-to-hip x-distance) | |
| 10 | left_hip_y | raw MediaPipe y |
| 11 | right_hip_y | |
| 12 | torso_inclination / 90 | 0=vertical, 1=horizontal |
| 13 | wrist_rel_hip (hip_y − wrist_y) | positive = wrist above hip |

All angles computed via `calculate_angle()` in `pose_detector.py` (returns degrees 0–180).

### Inference Pipeline

```
pose_frames
    │
    ▼
extract_sequence_features()  →  (T, 14) float32
    │
    ▼
BiLSTM forward pass  →  softmax probs  →  predicted class + confidence
    │
    ├─ confidence < 0.40  ──────────────────────────┐
    │                                               ▼
    ├─ _physics_check() fails  ─────────────►  rule_based.detect_exercise_type()
    │
    ├─ exercise not in ANALYSERS (dynamic class)  →  _minimal_result() [rep_count=0]
    │
    ▼
return BiLSTM prediction + rule-based analyser result
```

**Physics constraints** — dict-based in `bilstm_analyser.PHYSICS_CONSTRAINTS`; exercises with no entry always pass:
- `jumping_jack`: knee_range ≤ 0.10 AND knee_min ≥ 0.85 AND wrist_max ≥ 0.10
- `plank`: knee_range ≤ 0.15 AND elbow_range ≤ 0.20
- `bicep_curl`: elbow_range ≥ 0.15 AND knee_range ≤ 0.15
- `squat`, `lunge`, new exercises: no constraint (always pass physics check)

### Training

**Current state:** Trained on augmented synthetic data. Achieves ~99–100% on synthetic test data.
Expected accuracy on real video: ~80–85% (domain gap reduced by augmentation).

**To retrain (synthetic):**
```bash
cd backend
python -m app.analysis.train_bilstm                    # synthetic + augmentation (default)
python -m app.analysis.evaluate_bilstm                 # generates eval_report.txt
```

**To train on real video data (recommended for best accuracy):**
```bash
# 1. Record 2–3 clips per exercise (~20s each), one exercise per clip.
#    Place in: data/real/videos/<label>/clip_01.mp4
#    The subdirectory name becomes the class label — no code changes needed.

# 2. Extract sequences (discovers classes from directory names)
cd backend
python -m app.analysis.preprocess_real_data \
    --data-dir data/real/videos \
    --out-dir  data/real/sequences

# 3. Train (mixed = real + synthetic fill, recommended)
python -m app.analysis.train_bilstm --mode mixed --real-data-dir data/real/sequences

# 4. Evaluate
python -m app.analysis.evaluate_bilstm
```

**Training modes:**

| Mode | Data | When to use |
|------|------|-------------|
| `synthetic` | Generated + augmented | Default; no recordings needed |
| `real` | `.npy` files from preprocess script | When you have enough real data (50+/class) |
| `mixed` | Real + synthetic fill | Best option when you have some real data |

**Synthetic augmentations** (applied in `_augment_sequence()`, `train_bilstm.py`):
- Mirror/flip — swaps L/R feature pairs (simulates body orientation variation)
- Time warp ±30% — simulates fast/slow reps and FPS variation
- Phase offset — starts sequences mid-rep
- Feature dropout (30% chance) — simulates partial occlusion

**Minimum real data for good results:** 2–3 clips × 20s per exercise class (~50–80 sequences/class after windowing). Pair with `--mode mixed` to fill gaps with synthetic data.

**Why real data matters:** Real data eliminates domain gap. Synthetic only → ~60–70% real-video accuracy; mixed with 50 real sequences → ~90%+.

### Tests

```bash
cd backend
pip install -r requirements-dev.txt
python -m pytest tests/ -v                          # 72 passed, 1 xfailed
python -m pytest tests/ --cov=app/analysis --cov-report=term-missing
```

- `tests/test_model.py` — architecture, shapes, determinism, parameter count
- `tests/test_features.py` — feature extractor unit tests (known-angle assertions)
- `tests/test_physics.py` — physics threshold boundary tests
- `tests/test_classify.py` — integration tests with monkeypatched features
- `backend/conftest.py` — stubs mediapipe/cv2 so tests run locally without Docker

---

## Adding a New Exercise

**With dynamic class support (no code changes needed):**
1. Record 2–3 video clips, place in `data/real/videos/<new_exercise_name>/`
2. Run `python -m app.analysis.preprocess_real_data`
3. Retrain: `python -m app.analysis.train_bilstm --mode mixed`
4. The new class is auto-discovered and embedded in weights — frontend renders it with `getExerciseLabel()` fallback

**For full rule-based analyser support (rep counting + form scoring):**
1. Create `backend/app/analysis/exercises/<name>.py` implementing `ExerciseAnalyser` from `base.py`
2. Register it in `app/analysis/bilstm_analyser.ANALYSERS` and `app/analysis/rule_based.py`
3. Optionally add to `PHYSICS_CONSTRAINTS` in `bilstm_analyser.py` if the exercise has hard motion constraints

Without a rule-based analyser, the new exercise will be classified correctly but `rep_count` and `form_score` will be 0 (BiLSTM classifies it; `_minimal_result()` is returned).
