import logging
import os
import time
import ollama

logger = logging.getLogger(__name__)

OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434")
MODEL = os.getenv("OLLAMA_MODEL", "llama3.2")
OLLAMA_TIMEOUT = int(os.getenv("OLLAMA_TIMEOUT", "30"))

_client = ollama.Client(host=OLLAMA_HOST, timeout=OLLAMA_TIMEOUT)

SYSTEM_PROMPT = """You are a professional fitness coach AI.
Analyse workout data and provide clear, encouraging, and actionable coaching feedback.
Keep responses concise (2-4 sentences per exercise). Be specific about form issues.
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


def answer_query(query: str, session_context: str) -> str:
    try:
        response = _client.chat(
            model=MODEL,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": f"Here is the workout data:\n{session_context}\n\nUser question: {query}",
                },
            ],
        )
        return response["message"]["content"]
    except Exception as e:
        logger.warning("Ollama unavailable for voice query: %s", e)
        return "I'm unable to answer right now — the AI coach is temporarily unavailable. Please try again shortly."
