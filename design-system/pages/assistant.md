# Page: AI Assistant

Route: /assistant
Purpose: Voice and text interface to query workout analytics using natural language.

---

## Layout
```
┌─────────────────────────────────────────────────────────────────┐
│  PAGE HEADER                                                    │
│  "AI Coach"  · "Ask anything about your workouts"              │
│  [Session context pill]: "Viewing: Mar 10 session" [× clear]   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  CONVERSATION AREA  (flex-1, overflow-y-auto)                  │
│  ─────────────────────────────────────────────                  │
│                                                                 │
│  [AI message - left aligned]                                   │
│  ┌──────────────────────────────────────────────────────┐      │
│  │ 🤖  [Bot icon]  AI Coach                            │      │
│  │ "Hello! I've loaded your workout from Mar 10.       │      │
│  │  You completed 3 exercises: Squats, Lunges, and     │      │
│  │  Jumping Jacks. What would you like to know?"       │      │
│  └──────────────────────────────────────────────────────┘      │
│  bg-surface rounded-xl rounded-tl-none p-4                      │
│  max-w-[70%]                                                    │
│                                                                 │
│  [User message - right aligned]                                 │
│                              ┌────────────────────────┐        │
│                              │  How was my squat form? │        │
│                              └────────────────────────┘        │
│                 bg-primary/15 border border-primary/20          │
│                 rounded-xl rounded-tr-none p-4 max-w-[70%]      │
│                                                                 │
│  [AI response]                                                  │
│  ┌──────────────────────────────────────────────────────┐      │
│  │  Your squat form scored 78% overall. You completed   │      │
│  │  14 reps with 11 marked as correct form. The main   │      │
│  │  issue was knees moving forward in 6 reps. Try      │      │
│  │  focusing on pushing your hips back at the start.  │      │
│  │                                                      │      │
│  │  [▶ Play response]  0:08                            │      │
│  └──────────────────────────────────────────────────────┘      │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  INPUT AREA (sticky bottom)                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  [Mic button]  Ask your AI coach...         [Send →]    │   │
│  └──────────────────────────────────────────────────────────┘   │
│  bg-surface-2, border-t border-white/7, px-4 py-3              │
└─────────────────────────────────────────────────────────────────┘
```

---

## Voice Interaction States

### Mic Button States
```
Idle:     bg-surface border border-white/10  [Mic icon — text-muted]
Hover:    bg-surface-2 border-primary/30     [Mic icon — text-primary]
Recording: bg-primary/15 border-primary animate-pulse [MicOff — text-primary]
           + "Listening..." text appears in input field
Processing: spinner icon, disabled
```

### Audio Playback (on AI response)
- Small inline player: [▶/⏸] icon + waveform bars (CSS animated) + duration
- bg-surface-3, rounded-lg, p-2
- Waveform: 5 bars, height animated with CSS keyframes during playback

---

## Suggested Questions (shown when conversation is empty)
```
Grid of 4 suggestion chips:
┌─────────────────────────┐ ┌─────────────────────────┐
│ How was my squat form?  │ │ How many reps total?    │
└─────────────────────────┘ └─────────────────────────┘
┌─────────────────────────┐ ┌─────────────────────────┐
│ What should I improve?  │ │ Compare to last session │
└─────────────────────────┘ └─────────────────────────┘
```
- Each chip: bg-surface border border-white/7 rounded-lg p-3 text-sm
- hover: border-primary/40 text-primary cursor-pointer

---

## Session Context Pill
- Shown at top when a session is pre-loaded
- bg-primary/10 border border-primary/20 rounded-full px-3 py-1
- text-xs text-primary/80 + session date
- [×] to clear context (returns to general mode, answers from full history)

---

## Component Notes
- Message list: auto-scroll to bottom on new message
- Timestamp on each message: text-xs text-muted on hover only
- Text input: bg-surface border border-white/10 rounded-xl px-4 py-3
  placeholder text-muted, focus:border-primary/50 outline-none
- Send button: disabled when input empty, bg-primary when active
