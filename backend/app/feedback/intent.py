"""
Intent extraction for workout queries.

Extracts two parameters from a user query:
  - exercise : the specific exercise the user is asking about, or None (= whole workout)
  - day      : the temporal reference ("today", "yesterday", "week", "all")

Strategy
--------
1. Strip the Flutter-injected multi-session context prefix from the raw query.
2. Run keyword regex matching — fast, deterministic, covers ~95 % of real queries.
3. Return a typed IntentResult so callers can filter session data before the LLM call.

No LLM call is made here; the regex approach is sufficient and keeps latency low.
"""

import re
from dataclasses import dataclass, field

# ---------------------------------------------------------------------------
# Exercise vocabulary
# Each entry: (canonical_type, [trigger_phrases])
# Longer / more-specific phrases MUST come before shorter ones in each list
# so we match "bicep curl" before "curl".
# The outer list is also ordered: multi-word exercises first.
# ---------------------------------------------------------------------------
_EXERCISE_VOCAB: list[tuple[str, list[str]]] = [
    ("bicep_curl",   ["bicep curl", "bicep curls", "arm curl", "arm curls", "bicep", "curl", "curls"]),
    ("jumping_jack", ["jumping jack", "jumping jacks", "jumping", "jacks", "jack"]),
    ("squat",        ["squat", "squats"]),
    ("lunge",        ["lunge", "lunges"]),
    ("plank",        ["plank", "planks"]),
]

# ---------------------------------------------------------------------------
# Day / temporal vocabulary
# ---------------------------------------------------------------------------
_DAY_VOCAB: list[tuple[str, list[str]]] = [
    ("yesterday", ["yesterday"]),
    ("week",      ["this week", "past week", "last week", "past few days"]),
    ("today",     ["today", "this morning", "this afternoon", "this evening", "just now", "earlier"]),
    # "all" is the catch-all — no trigger phrases; used as the fallback only
    # when the user asks something like "show all my sessions".
]

_ALL_TRIGGER = re.compile(
    r"\b(all\s+(?:my\s+)?(?:sessions?|history|workouts?|time))\b", re.IGNORECASE
)

# ---------------------------------------------------------------------------
# Context-prefix stripper
# The Flutter app prepends:
#   "Today's full workout: jumping_jack (25 reps, 100% form); squat (12 reps, 85% form). "
# Strip it before intent analysis so it doesn't confuse exercise detection.
# ---------------------------------------------------------------------------
_CONTEXT_PREFIX_RE = re.compile(
    r"^today'?s?\s+(?:full\s+)?workout\s*:.*?\.\s*",
    re.IGNORECASE,
)


# ---------------------------------------------------------------------------
# Public types
# ---------------------------------------------------------------------------

@dataclass
class IntentResult:
    """Result of intent extraction from a user query."""

    exercise: str | None   # canonical exercise type (e.g. "squat") or None = all
    day: str               # "today" | "yesterday" | "week" | "all"
    clean_query: str       # query with context-prefix stripped — use this for LLM calls


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def strip_context_prefix(text: str) -> str:
    """Remove the Flutter-injected multi-session context prefix from a query."""
    return _CONTEXT_PREFIX_RE.sub("", text).strip()


def extract_intent(query: str) -> IntentResult:
    """
    Parse a user query and return the extracted exercise + day intent.

    Parameters
    ----------
    query:
        Raw query text, potentially prefixed with the Flutter context string.

    Returns
    -------
    IntentResult with:
      - exercise = canonical type if a single exercise is mentioned, else None
      - day = temporal scope of the question
      - clean_query = query with the context prefix removed
    """
    clean = strip_context_prefix(query)
    lower = clean.lower()

    # ── Exercise detection ──────────────────────────────────────────────────
    exercise: str | None = None
    for canonical, phrases in _EXERCISE_VOCAB:
        for phrase in phrases:
            pattern = rf"\b{re.escape(phrase)}\b"
            if re.search(pattern, lower):
                exercise = canonical
                break
        if exercise is not None:
            break

    # ── Day detection ───────────────────────────────────────────────────────
    day = "today"  # sensible default
    if _ALL_TRIGGER.search(lower):
        day = "all"
    else:
        for day_label, phrases in _DAY_VOCAB:
            for phrase in phrases:
                pattern = rf"\b{re.escape(phrase)}\b"
                if re.search(pattern, lower):
                    day = day_label
                    break
            if day != "today":
                break

    return IntentResult(exercise=exercise, day=day, clean_query=clean)
