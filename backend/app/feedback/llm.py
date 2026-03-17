import logging
import os
import time
import ollama

logger = logging.getLogger(__name__)

OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434")
MODEL = os.getenv("OLLAMA_MODEL", "llama3.2")
OLLAMA_TIMEOUT = int(os.getenv("OLLAMA_TIMEOUT", "30"))

_client = ollama.Client(host=OLLAMA_HOST, timeout=OLLAMA_TIMEOUT)

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
    logger.info("Sending request to Ollama | model=%s host=%s timeout=%ds", MODEL, OLLAMA_HOST, OLLAMA_TIMEOUT)
    t = time.perf_counter()
    try:
        response = _client.chat(
            model=MODEL,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": f"{workout_context}\n\nPlease provide coaching feedback for this workout."},
            ],
        )
        text = response["message"]["content"]
        logger.info("Ollama responded in %.2fs | %d chars", time.perf_counter() - t, len(text))
        return text
    except Exception as e:
        logger.warning("Ollama unavailable (%.2fs): %s — returning fallback feedback", time.perf_counter() - t, e)
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
        # For greetings / small-talk: don't pass workout data — let the LLM
        # respond naturally without being anchored to exercise numbers.
        if _is_small_talk(query):
            user_content = query
        else:
            user_content = f"Here is the workout data:\n{session_context}\n\nUser question: {query}"

        response = _client.chat(
            model=MODEL,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_content},
            ],
        )
        return response["message"]["content"]
    except Exception as e:
        logger.warning("Ollama unavailable for voice query: %s", e)
        return "I'm unable to answer right now — the AI coach is temporarily unavailable. Please try again shortly."
