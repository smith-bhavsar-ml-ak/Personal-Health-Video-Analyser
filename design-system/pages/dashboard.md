# Page: Dashboard

Route: /
Purpose: Overview of all workout history, key stats at a glance, quick access to analyze.

---

## Layout — Bento Grid

```
┌─────────────────────────────────────────────────────────────────┐
│ HEADER: "Good morning" + date + "Start Analysis" CTA button     │
├──────────────┬──────────────┬──────────────┬────────────────────┤
│  Total       │  Sessions    │  Avg Form    │  Streak            │
│  Reps        │  This Week   │  Score       │  Days              │
│  [big num]   │  [big num]   │  [big num]%  │  [big num]         │
│  ↑ vs last   │  ↑ vs last   │  ↑ vs last   │  🔥 keep going     │
│  week        │  week        │  week        │                    │
├──────────────┴──────────────┴──────────────┴────────────────────┤
│  AREA CHART — Form Score Trend (last 10 sessions)               │
│  x-axis: session dates   y-axis: 0–100                          │
│  chart-1 (indigo) fill under curve, subtle                      │
├────────────────────────────────┬────────────────────────────────┤
│  RECENT SESSIONS               │  EXERCISE BREAKDOWN            │
│  ─────────────────────         │  ──────────────────────        │
│  List of last 5 sessions:      │  RadialBarChart                │
│  [date] [exercises] [score]    │  % split across 5 exercises    │
│  chevron → to session detail   │  color per exercise type       │
│                                │                                │
├────────────────────────────────┴────────────────────────────────┤
│  QUICK UPLOAD CARD                                              │
│  "Analyze a new workout" + upload icon + drag-drop zone         │
│  border-dashed border-white/10 hover:border-primary             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Stat Card Spec
- 4 cards in a row (grid-cols-4)
- Each: bg-surface, border, rounded-xl, p-5
- Big number: text-4xl font-bold text-primary (or health for positive)
- Label: text-sm text-muted uppercase tracking-wide
- Delta: text-xs text-health (↑) or text-error (↓) with arrow icon

## Chart Spec — Form Score Trend
- Type: AreaChart (Recharts)
- Height: 200px
- Stroke: --chart-1 (#6366F1)
- Fill: rgba(99,102,241,0.08)
- No dots on line, smooth curve
- Tooltip: custom dark tooltip

## Recent Sessions List
- Each row: flex justify-between items-center py-3 border-b border-white/5
- Left: date (text-sm text-secondary) + exercise badges
- Right: form score badge (color-coded) + ChevronRight

## Exercise Breakdown
- RadialBarChart, compact (height 180px)
- Legend below with exercise name + percentage
- 5 colors from chart token palette
