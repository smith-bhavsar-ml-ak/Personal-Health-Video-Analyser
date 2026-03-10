# Page: Analyze

Route: /analyze
Purpose: Single-page flow — upload video → show processing state → reveal results inline.
Routing decision: Upload + results on SAME page (no redirect). Results slide in below upload zone after processing.

---

## Layout — Vertical Single Page Flow

### Phase 1: Upload State
```
┌─────────────────────────────────────────────────────────┐
│  PAGE HEADER                                            │
│  "Analyze Workout"   subtitle: "Upload a workout video" │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │           UPLOAD ZONE (drag & drop)             │   │
│  │                                                 │   │
│  │        [Upload icon — Lucide Upload]            │   │
│  │   "Drag your workout video here"                │   │
│  │   "or click to browse"                          │   │
│  │   Supported: MP4, MOV, AVI · Max 2 min          │   │
│  │                                                 │   │
│  └─────────────────────────────────────────────────┘   │
│  border-2 border-dashed border-white/10                 │
│  hover: border-primary/50 bg-primary/5                  │
│  rounded-2xl min-h-[240px]                              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Phase 2: Processing State
```
┌─────────────────────────────────────────────────────────┐
│  Upload zone → replaced by progress card                │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  [Spinner]  Analyzing your workout...           │   │
│  │                                                 │   │
│  │  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░  Step 2 of 4           │   │
│  │  Detecting pose landmarks...                    │   │
│  │                                                 │   │
│  │  ✓ Frame extraction complete (147 frames)       │   │
│  │  ⟳ Running pose detection...                   │   │
│  │  ○ Exercise recognition                         │   │
│  │  ○ Generating AI feedback                       │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```
- Progress bar: bg-primary/20 filled with bg-primary
- Step list: completed = CheckCircle text-health, active = spinner, pending = circle text-muted

### Phase 3: Results State (slides in below, upload stays for re-analysis)
```
┌─────────────────────────────────────────────────────────┐
│  RESULTS HEADER                                         │
│  "Analysis Complete" + session timestamp                │
│  [Save Session] [Analyze Another] buttons               │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  EXERCISE SETS  (one card per detected exercise)        │
│  ┌────────────────────────────────────────────────┐    │
│  │  [Exercise badge]  SQUAT          [Score: 78%] │    │
│  │                                                │    │
│  │  14 reps  ·  11 correct  ·  42s               │    │
│  │                                                │    │
│  │  BarChart: form score per rep                  │    │
│  │  (green bars = correct, amber/red = errors)    │    │
│  │                                                │    │
│  │  POSTURE ISSUES                                │    │
│  │  ● Knees moving forward   — 6 times  [medium] │    │
│  │  ● Back leaning forward   — 3 times  [low]    │    │
│  └────────────────────────────────────────────────┘    │
│                                                         │
│  (repeat card for each exercise detected)               │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  AI COACHING FEEDBACK                                   │
│  ┌────────────────────────────────────────────────┐    │
│  │  [MessageSquare icon]  AI Coach                │    │
│  │                                                │    │
│  │  "You completed 14 squats with good depth.     │    │
│  │  Try keeping your knees behind your toes for   │    │
│  │  better form. Your jumping jacks were          │    │
│  │  excellent — consistent timing and range."     │    │
│  └────────────────────────────────────────────────┘    │
│  bg-surface-3, border-l-2 border-primary               │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  VOICE QUERY SHORTCUT                                   │
│  "Ask your AI Coach a question" [mic button]            │
│  Links to /assistant with session context pre-loaded    │
└─────────────────────────────────────────────────────────┘
```

---

## Interaction Notes
- Upload zone: onDragOver changes border to primary, bg tints indigo
- File selected: show filename + duration + file size + [Remove] × button
- Analyze button: disabled until file selected, loading spinner during upload
- Results animation: fadeInUp 200ms staggered per card (0ms, 80ms, 160ms...)
- Exercise card expand/collapse: click header to toggle rep chart
