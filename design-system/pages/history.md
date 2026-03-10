# Page: Workout History

Route: /history
Purpose: Browsable list of all past sessions with filtering and summary stats.

---

## Layout
```
┌─────────────────────────────────────────────────────────────────┐
│  HEADER: "Workout History"                                      │
│  [Filter: All | This Week | This Month] [Sort: Newest ▾]       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  HISTORY TABLE / LIST                                           │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Date          Exercises        Reps   Score    Duration  │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │  Mar 10, 2026  [Squat][Lunge]   47     82%      4m 32s   │  │
│  │  Mar 8, 2026   [Squat][JJ]      38     74%      3m 10s   │  │
│  │  Mar 6, 2026   [Bicep Curl]     30     91%      2m 45s   │  │
│  └───────────────────────────────────────────────────────────┘  │
│  Each row: hover bg-surface-2, cursor-pointer → /session/[id]  │
│  Zebra striping: none (clean flat list)                         │
│  Row border: border-b border-white/5                            │
│                                                                 │
│  Empty state:                                                   │
│  [Video icon]  "No sessions yet"                               │
│  "Upload your first workout to get started"                    │
│  [Analyze Workout →] button                                    │
└─────────────────────────────────────────────────────────────────┘
```

## Table Spec
- No separate table/grid component — use standard HTML table with Tailwind
- th: text-xs text-muted uppercase tracking-widest font-medium
- td: text-sm text-secondary py-4
- Exercise badges inline: small colored chips per exercise type
- Score: color-coded badge (green/amber/red)
- Row click: navigates to /session/[id]

## Filter Tabs
- Inline pill tabs: bg-surface-2 rounded-lg p-1
- Active tab: bg-surface-3 text-primary font-medium shadow-sm
- Inactive: text-muted hover:text-secondary
