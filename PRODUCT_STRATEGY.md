# PHVA — Product Strategy & Roadmap

> Personal Health Video Analyzer
> Last updated: 2026-03-18
> Status: Pre-revenue / POC → Production transition

---

## 1. Core USP (Unique Selling Propositions)

These are the reasons a user picks PHVA over Nike Training Club, Freeletics, or a personal trainer.

### Primary USP
> **"Your phone is your personal trainer. Upload any workout video and get instant AI form analysis, rep counts, and coaching — no wearable, no gym equipment, no subscription needed to start."**

### Supporting USPs

| # | USP | Why it matters |
|---|-----|---------------|
| 1 | **CV-powered form scoring** | No other mainstream free app analyses *your own* video for form quality. Most apps show demo videos — PHVA watches *you*. |
| 2 | **No wearable required** | Works with any smartphone camera. $0 hardware barrier. Huge in emerging markets (India, Brazil, SEA). |
| 3 | **Privacy-first by default** | Video is processed and discarded. No biometric data stored in cloud. GDPR-safe by design. |
| 4 | **AI coach that knows your history** | Feedback is contextual — it knows your past sessions, weak points, and current plan. Not generic tips. |
| 5 | **Walking + workout in one app** | Step tracking + GPS run/walk + video analysis = complete activity picture without switching apps. |
| 6 | **Workout plan that auto-updates** | After you upload a video, the plan marks itself done. No manual logging. |

---

## 2. Exercise Expansion — 40+ Target

### Current (5 exercises)
`squat`, `jumping_jack`, `bicep_curl`, `lunge`, `plank`

### Target Exercise Library (Phase 1 — 40 exercises)

#### Push (8)
| exercise_type | Display Name | Equipment |
|---------------|-------------|-----------|
| `push_up` | Push Up | None |
| `diamond_push_up` | Diamond Push Up | None |
| `wide_push_up` | Wide Push Up | None |
| `pike_push_up` | Pike Push Up | None |
| `shoulder_press` | Shoulder Press | Dumbbells |
| `lateral_raise` | Lateral Raise | Dumbbells |
| `tricep_dip` | Tricep Dip | Chair |
| `tricep_extension` | Tricep Extension | Dumbbells |

#### Pull / Back (4)
| exercise_type | Display Name | Equipment |
|---------------|-------------|-----------|
| `pull_up` | Pull Up | Bar |
| `bent_over_row` | Bent Over Row | Dumbbells |
| `reverse_fly` | Reverse Fly | Dumbbells |
| `good_morning` | Good Morning | Bodyweight |

#### Lower Body (10)
| exercise_type | Display Name | Equipment |
|---------------|-------------|-----------|
| `sumo_squat` | Sumo Squat | None |
| `split_squat` | Split Squat | None |
| `jump_squat` | Jump Squat | None |
| `glute_bridge` | Glute Bridge | None |
| `hip_thrust` | Hip Thrust | None |
| `romanian_deadlift` | Romanian Deadlift | Dumbbells |
| `step_up` | Step Up | Box/Chair |
| `wall_sit` | Wall Sit | None |
| `calf_raise` | Calf Raise | None |
| `donkey_kick` | Donkey Kick | None |

#### Core (8)
| exercise_type | Display Name | Equipment |
|---------------|-------------|-----------|
| `sit_up` | Sit Up | None |
| `crunch` | Crunch | None |
| `bicycle_crunch` | Bicycle Crunch | None |
| `leg_raise` | Leg Raise | None |
| `russian_twist` | Russian Twist | None |
| `mountain_climber` | Mountain Climber | None |
| `side_plank` | Side Plank | None |
| `plank_shoulder_tap` | Plank Shoulder Tap | None |

#### Cardio / Full Body (6)
| exercise_type | Display Name | Equipment |
|---------------|-------------|-----------|
| `burpee` | Burpee | None |
| `high_knee` | High Knee | None |
| `butt_kick` | Butt Kick | None |
| `jumping_lunge` | Jumping Lunge | None |
| `box_jump` | Box Jump | Box |
| `lateral_shuffle` | Lateral Shuffle | None |

#### Yoga / Flexibility (4)
| exercise_type | Display Name | Equipment |
|---------------|-------------|-----------|
| `downward_dog` | Downward Dog | Mat |
| `warrior_pose` | Warrior Pose | Mat |
| `child_pose` | Child's Pose | Mat |
| `cobra_pose` | Cobra Pose | Mat |

### Training Plan for Each Exercise
- Record **3–5 clips × 20s** per exercise (different people, angles, speeds)
- Place in `data/real/videos/<exercise_type>/clip_01.mp4`
- Run `python -m app.analysis.preprocess_real_data`
- Retrain: `python -m app.analysis.train_bilstm --mode mixed`
- Evaluate: `python -m app.analysis.evaluate_bilstm`
- Target: ≥85% real-video accuracy per class

**Muscle group metadata to add to DB** (enables plan balance analysis):
```
exercise_metadata table:
  exercise_type → primary_muscles[], secondary_muscles[], movement_pattern, difficulty, equipment
```

---

## 3. Walking & Activity Tracking

### Architecture
No CV pipeline needed — uses phone sensors directly in the Flutter app.

| Feature | Flutter Package | Data |
|---------|----------------|------|
| Step counting | `pedometer` | steps/day, cadence |
| GPS walk/run | `geolocator` + `flutter_polyline_points` | distance, pace, route map |
| Active minutes | Derived from step cadence | minutes in zone |
| Calorie estimate | Steps × weight × MET formula | kcal burned |

### New DB Tables Required
```sql
activity_sessions (
  id, user_id, type,           -- 'walk' | 'run' | 'hike'
  started_at, ended_at,
  steps INT,
  distance_m FLOAT,
  avg_pace_s_per_km FLOAT,
  calories_burned FLOAT,
  gps_polyline TEXT,           -- encoded polyline for map display
  elevation_gain_m FLOAT
)

daily_step_logs (
  id, user_id, date DATE,
  steps INT, goal INT,         -- default 10,000
  calories_burned FLOAT,
  active_minutes INT
)
```

### UI Flow
- Home screen widget: Today's steps (ring chart) + last walk distance
- Dedicated "Activity" tab (between History and Progress)
- Live tracking screen: map + live pace + elapsed time + steps
- Post-walk summary card (shareable — same as workout share card)

---

## 4. Workout Share Card

### Design Spec
When user taps Share on a session or activity, generate an image card:

```
┌────────────────────────────────────────────────┐
│  [PHVA gradient background — dark indigo/teal] │
│                                                │
│  🏋️  Jumping Jack                              │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                                │
│   25 reps    100% form    26s duration         │
│                                                │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  Form Score: 100       │
│                                                │
│  "Crushed it! Perfect form on all 25 reps."   │
│                   — AI Coach                   │
│                                                │
│  📅 March 17, 2026    🔥 3-day streak          │
│              [PHVA logo]                       │
└────────────────────────────────────────────────┘
```

### Implementation
```dart
// Flutter: use RepaintBoundary + RenderRepaintBoundary
final boundary = globalKey.currentContext!
    .findRenderObject() as RenderRepaintBoundary;
final image = await boundary.toImage(pixelRatio: 3.0);
final bytes = await image.toByteData(format: ImageByteFormat.png);
// Share via share_plus
await Share.shareXFiles([XFile.fromData(bytes!.buffer.asUint8List(),
    mimeType: 'image/png')], text: 'My workout on PHVA');
```

For walk/run cards — show route map thumbnail + distance + pace + steps.

---

## 5. Subscription Tiers

### Tier Design Principles
- **Free tier must be genuinely useful** — not crippled. Hook users with value, upsell on volume/depth.
- **Pro tier is the primary revenue driver** — priced for individuals.
- **Elite tier is for serious athletes and trainers** — priced for outcomes.

---

### Free Tier — "Starter"
**Price: $0 forever**

| Feature | Limit |
|---------|-------|
| Video analyses | 5 per month |
| Active workout plans | 1 |
| Exercise library | 5 core exercises (current set) |
| AI coaching feedback | Basic (3 sentences, no history context) |
| Walking tracking | Steps only (no GPS) |
| Progress charts | 30 days |
| Weight logging | ✅ Unlimited |
| Share cards | ✅ with PHVA watermark |
| Voice AI assistant | ❌ |
| Plan generation (AI) | 1 per month |

**Goal:** Get users hooked on the form analysis. 5 analyses/month is enough to feel the value but not enough for a serious trainer.

---

### Pro Tier — "Athlete"
**Price: $7.99/month | $59.99/year (save 37%)**

| Feature | Limit |
|---------|-------|
| Video analyses | 60 per month |
| Active workout plans | Unlimited |
| Exercise library | All 40+ exercises |
| AI coaching feedback | Full context-aware (history, weak points, goals) |
| Walking tracking | Steps + GPS route + pace + elevation |
| Progress charts | Full history |
| Weight logging | ✅ + trend prediction |
| Share cards | ✅ no watermark |
| Voice AI assistant | ✅ 100 queries/month |
| Plan generation (AI) | Unlimited |
| Streak tracking | ✅ |
| Achievements & badges | ✅ |
| Body measurements | ✅ (waist, chest, arms) |
| Rest timer | ✅ in-plan |
| Export data | CSV |

---

### Elite Tier — "Performance"
**Price: $14.99/month | $119.99/year (save 33%)**

Everything in Pro, plus:

| Feature | Detail |
|---------|--------|
| Video analyses | Unlimited |
| Voice AI assistant | Unlimited |
| Real-time form correction | Live camera overlay (when shipped) |
| Advanced analytics | Muscle balance, volume load, fatigue score |
| Progressive overload tracking | Weight + reps tracked per set per week |
| Workout templates library | Access to 50+ expert-built programs |
| Progress photos | Before/after with AI body composition estimate |
| Priority processing | Video analysis queue priority |
| Early access | Beta features first |
| Data export | CSV + PDF + API access |
| Multiple profiles | Up to 3 users (family plan) |

---

### Trainer Tier — "Coach" (Future — Phase 2)
**Price: $29.99/month**

For certified personal trainers:
- Create and publish plan templates (earn revenue share)
- Manage up to 20 client accounts
- Client progress dashboard
- Branded share cards (trainer logo)
- Video review and annotation tools

---

### Revenue Projections (Conservative)

| Users | Free | Pro (5%) | Elite (1%) | MRR |
|-------|------|----------|------------|-----|
| 1,000 | 940 | 50 × $7.99 | 10 × $14.99 | $549 |
| 5,000 | 4,700 | 250 × $7.99 | 50 × $14.99 | $2,747 |
| 10,000 | 9,400 | 500 × $7.99 | 100 × $14.99 | $5,494 |
| 50,000 | 47,000 | 2,500 × $7.99 | 500 × $14.99 | $27,472 |
| 100,000 | 94,000 | 5,000 × $7.99 | 1,000 × $14.99 | $54,945 |

Industry benchmark: fitness apps convert 3–8% free → paid.

---

## 6. Infrastructure Cost Analysis

### Self-Hosted (Current / Near-term — keep costs at $0)
Run on your own machine or a single VPS. Suitable up to ~200 concurrent users.

| Component | Option | Monthly Cost |
|-----------|--------|-------------|
| Server | Your own machine / Raspberry Pi 5 | $0 |
| Database | PostgreSQL (local Docker) | $0 |
| LLM | Ollama (local) | $0 |
| Video storage | Local disk / NAS | $0 |
| Domain | Namecheap/Cloudflare | ~$1 |
| **Total** | | **~$1/month** |

**Ceiling:** ~50 concurrent users before response times degrade.

---

### Tier 1 — Starter Cloud ($20–60/month)
Suitable for 0–500 monthly active users. Single VPS, no redundancy.

| Component | Service | Spec | Monthly Cost |
|-----------|---------|------|-------------|
| App server + Ollama | Hetzner CX31 or DigitalOcean | 4 vCPU, 8GB RAM | $20–24 |
| Database | Managed PostgreSQL (basic) | 1 vCPU, 1GB | $15 |
| Video storage | Backblaze B2 | 100GB | $1 |
| CDN | Cloudflare (free tier) | — | $0 |
| Domain + SSL | Cloudflare | — | $1 |
| Backups | Hetzner snapshots | — | $2 |
| **Total** | | | **~$39–42/month** |

**Break-even:** 5–6 Pro subscribers.

---

### Tier 2 — Growth Cloud ($150–250/month)
Suitable for 500–5,000 MAU. Redundant, video queue, CDN.

| Component | Service | Spec | Monthly Cost |
|-----------|---------|------|-------------|
| App servers | 2× Hetzner CX41 | 4 vCPU, 16GB RAM each | $56 |
| Video worker | 1× Hetzner CCX23 (Celery) | 4 vCPU, 16GB RAM | $28 |
| Ollama inference | Hetzner CX51 | 8 vCPU, 32GB RAM | $56 |
| Database | Managed PostgreSQL | 2 vCPU, 4GB + 1 replica | $50 |
| Redis | Managed Redis | 1GB | $15 |
| Video storage | Backblaze B2 | 1TB | $6 |
| CDN | Bunny.net | ~500GB bandwidth | $5 |
| Load balancer | Hetzner LB11 | — | $8 |
| Monitoring | Sentry (free) + Uptime Robot (free) | — | $0 |
| **Total** | | | **~$224/month** |

**Break-even:** 28–30 Pro subscribers.

---

### Tier 3 — Scale Cloud ($800–1,200/month)
Suitable for 5,000–50,000 MAU. Auto-scaling, HA, GPU inference.

| Component | Service | Spec | Monthly Cost |
|-----------|---------|------|-------------|
| Kubernetes cluster | AWS EKS / GKE | 3× t3.xlarge nodes | $350 |
| GPU inference | Hetzner GX (or Lambda Labs) | 1× A10 24GB GPU | $200 |
| Database | AWS RDS PostgreSQL | db.t3.medium + 2 replicas | $180 |
| Redis | AWS ElastiCache | r6g.large | $100 |
| Video storage | AWS S3 | 10TB | $230 |
| CDN | CloudFront | 10TB transfer | $80 |
| Load balancer | AWS ALB | — | $25 |
| Monitoring | Sentry Team + Datadog | — | $75 |
| Celery workers | 3× t3.medium | — | $90 |
| **Total** | | | **~$1,330/month** |

**Break-even:** 167 Pro subscribers.

---

### Cost Comparison: Self-hosted Ollama vs Cloud LLM (per 10,000 analyses)

| LLM Option | Cost per analysis | 10K analyses/month |
|------------|------------------|--------------------|
| Ollama (self-hosted, Tier 2 server) | ~$0.002 (electricity/amortised) | ~$20 (included in server cost) |
| OpenAI GPT-4o-mini | ~$0.003 | ~$30 |
| Anthropic Claude Haiku | ~$0.002 | ~$20 |
| Google Gemini 1.5 Flash | ~$0.001 | ~$10 |
| OpenAI GPT-4o | ~$0.025 | ~$250 |

**Recommendation:** Keep Ollama self-hosted through Tier 2. Switch to Claude Haiku or Gemini Flash when moving to Tier 3 (cost is negligible at that scale).

---

## 7. Sprint Roadmap (Updated)

### Sprint 1 — Foundation (3–4 weeks)
**Goal:** Make the core loop work seamlessly.

- [ ] **Auto-progress tracking** — after video analysis completes, auto-mark matching plan exercises for today as done
- [ ] **OAuth login** — Google Sign-In + Apple Sign-In (kills friction, biggest conversion win)
- [ ] **S3 / Backblaze B2 video storage** — store processed videos for 30 days (Pro feature: replay)
- [ ] **Workout Share Card** — `RepaintBoundary` → PNG → `share_plus` with branded background

### Sprint 2 — Exercise Expansion (4–6 weeks)
**Goal:** Cover 80% of home workout movements.

- [ ] Record video clips for 35 new exercises (see §2 table)
- [ ] Preprocess + retrain BiLSTM with `--mode mixed`
- [ ] Add `exercise_metadata` DB table (muscle groups, difficulty, equipment)
- [ ] Add physics constraints for new exercises in `bilstm_analyser.py`
- [ ] Update `exercise_helpers.dart` with labels and colors for all 40 types
- [ ] Update Library screen with full exercise catalog + filter by muscle group

### Sprint 3 — Plans Upgrade (3–4 weeks)
**Goal:** Plans that track real training progress.

- [ ] Add `workout_logs` table (actual reps/weight/RPE per set)
- [ ] Add `weight_kg` and `rest_seconds` to `plan_exercises`
- [ ] Progressive overload suggestions (if you hit target reps 3 sessions in a row → increase)
- [ ] Muscle group balance heatmap (weekly volume by muscle group)
- [ ] Plan templates library (10 pre-built programs: PPL, Full Body 3x, HIIT 4x, etc.)

### Sprint 4 — Retention (2–3 weeks)
**Goal:** Users come back every day.

- [ ] **Streak tracking** (daily workout or step goal = counts)
- [ ] **Achievements** — 15 badges: first workout, 7-day streak, 100 reps, perfect form, etc.
- [ ] **Push notifications** — workout reminders, streak at risk, plan day reminder (Firebase FCM)
- [ ] **Rest timer** — in-plan countdown between sets with haptic feedback

### Sprint 5 — Walking & Activity (2–3 weeks)
**Goal:** Capture all daily movement, not just gym sessions.

- [ ] Pedometer integration (`pedometer` package) — daily step count, goal ring on home screen
- [ ] GPS activity tracking (`geolocator`) — walk/run with live map, pace, distance
- [ ] `activity_sessions` + `daily_step_logs` DB tables
- [ ] Activity share card (route map + stats)
- [ ] Calories burned estimate (steps × weight × MET)

### Sprint 6 — Monetisation (2–3 weeks)
**Goal:** First paying users.

- [ ] Subscription gate logic (track usage, enforce limits per tier)
- [ ] In-app purchase — RevenueCat SDK (handles iOS App Store + Google Play billing)
- [ ] Paywall screens (tasteful, show value before asking for payment)
- [ ] Usage analytics (Mixpanel free tier — track funnels, feature usage)
- [ ] Referral system — "Invite a friend, both get 1 free month Pro"

### Sprint 7 — Global (3–4 weeks)
**Goal:** Remove all barriers for non-English markets.

- [ ] i18n with Flutter's `intl` + ARB files — initial: EN, ES, PT-BR, HI, ZH-Hans
- [ ] GDPR tools — data export endpoint, right to erasure, consent banner (EU)
- [ ] Imperial/metric toggle for all units (already partial in profile)
- [ ] Localized exercise names and coaching feedback language
- [ ] Multi-region CDN for video/assets (Cloudflare R2 — free 10GB)

---

## 8. Key Metrics to Track (from Day 1)

| Metric | Target (6 months) | How to measure |
|--------|------------------|----------------|
| DAU/MAU ratio | >20% | Mixpanel |
| Day-7 retention | >30% | Mixpanel |
| Analysis completion rate | >90% | Backend logs |
| Free→Pro conversion | >4% | RevenueCat |
| Average session per user/week | >2 | DB query |
| Share card generated / session | >15% | Backend logs |
| Crash-free sessions | >99.5% | Sentry |

---

## 9. Competitive Positioning

| App | What they do well | PHVA advantage |
|-----|------------------|----------------|
| Nike Training Club | Huge exercise library, brand | CV form analysis — they have none |
| Freeletics | AI workout generation, community | Video analysis + no subscription to start |
| MyFitnessPal | Nutrition + steps | Exercise form scoring — they have none |
| Strava | Running/cycling GPS | Strength training + form analysis |
| Fitbod | Workout planning, progressive overload | Video analysis, walking, no wearable |
| Future | Human coaching via video | AI-powered at fraction of cost ($19/month vs $149/month) |

**Whitespace PHVA owns:** AI video form analysis + walking + workout planning + AI coaching in one app, free to start, no wearable.

---

## 10. Technical Debt to Address Before Launch

| Item | Priority | Effort |
|------|----------|--------|
| Celery/Redis task queue (video processing) | High | 2 days |
| `squats` → `squat` data sanitisation in plan generator | Done ✅ | — |
| `rep_scores = None` response fix | Done ✅ | — |
| Theme system (adaptive light/dark) | Done ✅ | — |
| Back navigation from session detail | Done ✅ | — |
| API rate limiting per user (not just IP) | Medium | 1 day |
| Video file size validation (server-side) | Medium | 0.5 days |
| Automated DB backups | High | 0.5 days |
| Sentry error tracking (free tier) | High | 1 day |
| BiLSTM confidence threshold tuning | Medium | 1 day |
