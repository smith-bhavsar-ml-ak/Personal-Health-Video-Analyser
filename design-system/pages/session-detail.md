# Page: Session Detail

Route: /session/[id]
Purpose: Deep-dive analytics for a single workout session.

---

## Layout
```
┌─────────────────────────────────────────────────────────────────┐
│  BREADCRUMB: History > Session · Mar 10, 2026 · 3:42 PM        │
│  [← Back to History]                                           │
├──────────────────────────────────────────────────────────────── │
│  SESSION SUMMARY ROW                                            │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌──────────┐  │
│  │ Total Reps  │ │  Exercises  │ │  Duration   │ │  Score   │  │
│  │     47      │ │      3      │ │   4m 32s    │ │   82%    │  │
│  └─────────────┘ └─────────────┘ └─────────────┘ └──────────┘  │
├──────────────┬──────────────────────────────────────────────────┤
│  EXERCISE    │  DETAIL PANEL                                    │
│  SELECTOR    │                                                  │
│  ──────────  │  SQUAT DETAIL                                    │
│  > Squat     │  ──────────────────────────────                  │
│    Lunge     │  Rep-by-rep BarChart (height 220px)              │
│    Jumping   │  x: rep number  y: form score 0–100             │
│    Jack      │  Color: green(>80) amber(60-80) red(<60)        │
│              │                                                  │
│  (vertical   │  POSTURE TIMELINE                               │
│  tab list,   │  Horizontal timeline showing when errors occur  │
│  left panel) │  Each error type = colored band on timeline     │
│              │                                                  │
│              │  POSTURE ERROR BREAKDOWN                        │
│              │  Horizontal BarChart (one bar per error type)   │
│              │  label: error name  value: occurrences          │
│              │                                                  │
│              │  IMPROVEMENT vs LAST SESSION                    │
│              │  Small comparison row:                          │
│              │  Form score: 78% → 82% (+4%) ↑ text-health     │
│              │  Correct reps: 11 → 13 (+2) ↑                  │
│              │  Errors: 9 → 6 (-3) ↑                          │
├──────────────┴──────────────────────────────────────────────────┤
│  AI FEEDBACK PANEL                                              │
│  Full coaching text, expandable                                 │
├─────────────────────────────────────────────────────────────────┤
│  VOICE QUERIES LOG                                              │
│  Q: "How was my squat form?" → A: "..."  [timestamp]           │
│  (collapsible list)                                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Component Notes

### Exercise Selector (Left Tab)
- Vertical list, each item: flex gap-3 items-center p-3 rounded-lg
- Active: bg-surface-2 border-l-2 border-primary text-primary
- Inactive: text-secondary hover:text-primary hover:bg-surface-2/50
- Shows exercise name + rep count + score badge

### Rep-by-Rep BarChart
- Recharts BarChart, height 220px
- Cell color based on score: fill={score > 80 ? '#10B981' : score > 60 ? '#F59E0B' : '#EF4444'}
- Tooltip: "Rep 7 — Score: 74% — Error: knee drift"
- Reference line at 80 (dashed, text-muted "Good threshold")

### Posture Error Breakdown
- Recharts HorizontalBarChart
- Each bar labeled with error name
- Color: amber for medium, red for high severity
- Value label at end of bar

### Comparison Metrics
- Small 3-col grid
- Each cell: label (text-xs text-muted) + value + delta (colored arrow + %)
