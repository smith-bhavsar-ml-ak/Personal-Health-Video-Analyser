import logging
import os
import time
from openai import OpenAI

logger = logging.getLogger(__name__)

# ── Groq config ───────────────────────────────────────────────────────────────
# Groq provides an OpenAI-compatible endpoint — drop-in replacement for Ollama.
# Sign up at console.groq.com → API Keys → create key → set GROQ_API_KEY.
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
# Default: llama-3.1-8b-instant (fast, free tier).
# Alternatives: llama-3.3-70b-versatile (smarter, higher rate limit cost)
MODEL = os.getenv("LLM_MODEL", "llama-3.1-8b-instant")
LLM_TIMEOUT = int(os.getenv("LLM_TIMEOUT", "30"))

# If no Groq key is set, the client will still be created but calls will fail
# gracefully — the fallback message is returned instead.
_client = OpenAI(
    api_key=GROQ_API_KEY or "no-key-set",
    base_url="https://api.groq.com/openai/v1",
    timeout=LLM_TIMEOUT,
)

SYSTEM_PROMPT = """You are a friendly, professional fitness coach AI named PHVA.

When the user sends a greeting (hi, hello, good morning, hey, etc.) or small talk
(thanks, thank you, bye, how are you, etc.), respond warmly and conversationally in
1-2 short sentences. Do NOT reference workout data for greetings or small talk.

When the user asks about their workout, analyse the provided workout data and give
clear, encouraging, actionable coaching feedback. Keep responses concise
(2-4 sentences per exercise). Be specific about form issues.
Use simple, motivating language. Never be discouraging."""

_FALLBACK = (
    "AI coaching feedback is temporarily unavailable. "
    "Please review the form score and posture issues above for guidance."
)


def generate_feedback(workout_context: str) -> str:
    logger.info("Sending request to Groq | model=%s timeout=%ds", MODEL, LLM_TIMEOUT)
    t = time.perf_counter()
    try:
        response = _client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": f"{workout_context}\n\nPlease provide coaching feedback for this workout."},
            ],
        )
        text = response.choices[0].message.content or ""
        logger.info("Groq responded in %.2fs | %d chars", time.perf_counter() - t, len(text))
        return text
    except Exception as e:
        logger.warning("Groq unavailable (%.2fs): %s — returning fallback feedback", time.perf_counter() - t, e)
        return _FALLBACK


_SMALL_TALK_TOKENS = {
    "hi", "hello", "hey", "hiya", "howdy",
    "thanks", "thank", "cheers", "appreciate",
    "bye", "goodbye", "cya",
    "good morning", "good afternoon", "good evening", "good night",
    "how are you", "what's up", "sup",
    "great", "awesome", "nice", "cool", "perfect",
    "ok", "okay", "got it", "sounds good", "sure",
    "welcome", "no problem",
}


def _is_small_talk(query: str) -> bool:
    """Return True when the query is a greeting or social phrase (≤ 6 words)."""
    lower = query.strip().lower()
    words = lower.split()
    if len(words) > 6:
        return False
    return any(
        lower == tok or lower.startswith(tok + " ") or lower.endswith(" " + tok)
        for tok in _SMALL_TALK_TOKENS
    )


def answer_query(query: str, session_context: str) -> str:
    try:
        if _is_small_talk(query):
            user_content = query
        else:
            user_content = f"Here is the workout data:\n{session_context}\n\nUser question: {query}"

        response = _client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_content},
            ],
        )
        return response.choices[0].message.content or ""
    except Exception as e:
        logger.warning("Groq unavailable for voice query: %s", e)
        return "I'm unable to answer right now — the AI coach is temporarily unavailable. Please try again shortly."
