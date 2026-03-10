import os
import ollama

OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434")
MODEL = "llama3.2"

_client = ollama.Client(host=OLLAMA_HOST)

SYSTEM_PROMPT = """You are a professional fitness coach AI.
Analyse workout data and provide clear, encouraging, and actionable coaching feedback.
Keep responses concise (2-4 sentences per exercise). Be specific about form issues.
Use simple, motivating language. Never be discouraging."""


def generate_feedback(workout_context: str) -> str:
    """
    Send structured workout metrics to Ollama llama3.2 and return coaching feedback.
    """
    response = _client.chat(
        model=MODEL,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"{workout_context}\n\nPlease provide coaching feedback for this workout."},
        ],
    )
    return response["message"]["content"]


def answer_query(query: str, session_context: str) -> str:
    """
    Answer a voice/text query about a specific workout session.
    """
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
