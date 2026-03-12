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

## Adding a New Exercise

1. Create `backend/app/analysis/exercises/<name>.py` implementing `ExerciseAnalyser` from `base.py`
2. Register it in `app/analysis/rule_based.py`
3. Add TypeScript type updates in `frontend/src/lib/types.ts` if new fields are returned
