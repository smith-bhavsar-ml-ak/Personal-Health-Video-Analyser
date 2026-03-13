# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal Health Video Analyser — a full-stack web app that analyzes fitness exercise form via video. Users upload workout videos; the backend extracts frames, runs MediaPipe pose detection, classifies exercises, scores form, and generates LLM coaching feedback via a local Ollama instance.

## Architecture

```
Video Upload → CV Pipeline → Exercise Analysis → LLM Feedback → Database → Frontend Display
```

**Backend (Python/FastAPI)** at `backend/`
- `app/main.py` — FastAPI entry point, CORS, DB init on startup
- `app/api/` — Routes: `sessions.py` (analyze, list, get, delete), `voice.py` (STT/TTS queries)
- `app/cv/` — Computer vision: `frame_extractor.py` → `pose_detector.py` → `pipeline.py`
- `app/analysis/` — Exercise analysis: `base.py` (abstract `ExerciseAnalyser`), `rule_based.py` (dispatcher), `exercises/` (squat, jumping_jack, bicep_curl, lunge, plank analyzers), `aggregator.py`
  - `bilstm_model.py` — PyTorch BiLSTM architecture (see BiLSTM section below)
  - `bilstm_analyser.py` — Drop-in `run_analysis()` using BiLSTM + physics checks + rule-based fallback
  - `features.py` — Extracts 14-dim float32 feature vector per PoseFrame
  - `train_bilstm.py` — Synthetic data generators + training loop; saves weights to `weights/bilstm_classifier.pt`
  - `evaluate_bilstm.py` — Standalone eval report: accuracy, noise robustness, speed (`python -m app.analysis.evaluate_bilstm`)
- `app/feedback/llm.py` — Ollama (llama3.2) integration for coaching feedback
- `app/voice/stt.py` — Whisper transcription; `voice/tts.py` — pyttsx3 TTS
- `app/db/` — Async SQLAlchemy with SQLite: `models.py`, `crud.py`, `database.py`

**Frontend (Next.js 14 / TypeScript)** at `frontend/`
- `src/app/` — App Router pages: `/` (dashboard), `/analyze`, `/history`, `/assistant`, `/session/[id]`
- `src/components/` — React components organized by page
- `src/lib/api.ts` — Typed fetch wrapper; `lib/types.ts` — shared TypeScript interfaces

**External dependency:** Ollama must be running locally on port 11434.

## Commands

### Backend
```bash
# Install
pip install -r backend/requirements.txt

# Run (dev with hot reload)
cd backend && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

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

# Production
docker-compose up
```

## Design System

All UI changes must follow `design-system/MASTER.md`. Key rules:
- **Dark mode only.** Primary: Indigo `#6366F1`, health/success: Emerald `#10B981`, warnings: Amber, errors: Red
- **Layout:** 240px fixed sidebar; fluid main with `max-w-7xl`; mobile sidebar collapses to bottom tab bar
- **Icons:** Lucide React, 24×24, 1.5px stroke
- **Charts:** Recharts only
- **Anti-patterns:** No gradients, no emoji, no glassmorphism, border-radius max 16px on cards

Page-specific design specs are in `design-system/pages/`.

## Key API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/sessions/analyze` | Upload video, run full analysis pipeline |
| GET | `/api/v1/sessions` | List all sessions |
| GET | `/api/v1/sessions/{id}` | Session details with exercise sets and feedback |
| DELETE | `/api/v1/sessions/{id}` | Delete session |
| POST | `/api/v1/sessions/{id}/voice` | Voice query on a session |
| GET | `/api/v1/health` | Health check |

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
Linear(128 → 5)  →  logits  (one per class)
```

- **Classes** (in order): `squat`, `jumping_jack`, `bicep_curl`, `lunge`, `plank`
- **Parameters**: ~576k
- **Weights file**: `backend/app/analysis/weights/bilstm_classifier.pt`

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
    ▼
return BiLSTM prediction
```

**Physics constraints** (hard overrides in `bilstm_analyser._physics_check`):
- `jumping_jack`: knee_range ≤ 0.10 AND knee_min ≥ 0.85 AND wrist_max ≥ 0.10
- `plank`: knee_range ≤ 0.15 AND elbow_range ≤ 0.20
- `bicep_curl`: elbow_range ≥ 0.15 AND knee_range ≤ 0.15
- `squat`, `lunge`: no physics constraints (rule-based handles edge cases)

### Training

**Current state:** Trained on synthetic data only. The synthetic generators in `train_bilstm.py` produce realistic 2D-projected MediaPipe angles (e.g. squat knee at 130–148° front-view, not the idealized 3D ~80°). Physics checks exist as a safety net to catch domain-gap errors on real video.

**To retrain:**
```bash
cd backend
python -m app.analysis.train_bilstm          # saves weights/bilstm_classifier.pt
python -m app.analysis.evaluate_bilstm       # generates eval_report.txt
# If running in Docker:
docker cp app/analysis/weights/bilstm_classifier.pt <container>:/app/app/analysis/weights/
```

**To train on real video data (recommended when available):**

1. Record 10–15 clips per exercise (~20–30 sec each), one exercise per clip.
   Name files: `data/real/squat_01.mp4`, `squat_02.mp4`, `jumping_jack_01.mp4`, etc.

2. Run the preprocessing script (to be written) which:
   - Passes each clip through the existing CV pipeline (`pipeline.py`)
   - Calls `extract_sequence_features()` on sliding 60-frame windows (stride 15)
   - Saves labeled numpy arrays to `data/real/sequences/<label>_<n>.npy`

3. Update `train_bilstm.py` to load real sequences (or mix real + synthetic):
   ```python
   # Replace or augment synthetic generators with:
   real_seqs = load_real_sequences("data/real/sequences/")
   # Mix: e.g. 80% real + 20% synthetic for data augmentation
   ```

4. Retrain and evaluate as above.

**Why real data matters:** A single person recording 10–15 videos per exercise class yields ~300–400 training sequences per class after windowing — sufficient for this BiLSTM size. Real data eliminates the domain gap between synthetic oscillation patterns and actual MediaPipe 2D projections.

**Recommended recording variations per exercise:**
- Different speeds (slow / normal / fast reps)
- Different depths (e.g. shallow vs deep squat)
- Different camera angles (front, 45°, side)
- Different positions in frame (centered, left, right)

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

1. Create `backend/app/analysis/exercises/<name>.py` implementing `ExerciseAnalyser` from `base.py`
2. Register it in `app/analysis/rule_based.py`
3. Add TypeScript type updates in `frontend/src/lib/types.ts` if new fields are returned
