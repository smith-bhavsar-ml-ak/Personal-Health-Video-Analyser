import base64
import tempfile
import os
import pyttsx3


def synthesise_speech(text: str) -> str:
    """
    Convert text to speech using pyttsx3.
    Returns base64-encoded WAV audio string.
    """
    engine = pyttsx3.init()
    engine.setProperty("rate", 175)   # words per minute
    engine.setProperty("volume", 0.9)

    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
        tmp_path = tmp.name

    try:
        engine.save_to_file(text, tmp_path)
        engine.runAndWait()

        with open(tmp_path, "rb") as f:
            audio_bytes = f.read()

        return base64.b64encode(audio_bytes).decode("utf-8")
    finally:
        os.unlink(tmp_path)
