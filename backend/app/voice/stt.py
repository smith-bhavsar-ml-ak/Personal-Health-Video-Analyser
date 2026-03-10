import base64
import tempfile
import os
import whisper

_model = None


def _get_model():
    global _model
    if _model is None:
        _model = whisper.load_model("base")  # ~74MB, CPU-friendly
    return _model


def transcribe_audio(audio_b64: str) -> str:
    """
    Decode base64 audio, transcribe with Whisper base model.
    Returns transcribed text.
    """
    audio_bytes = base64.b64decode(audio_b64)

    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
        tmp.write(audio_bytes)
        tmp_path = tmp.name

    try:
        model = _get_model()
        result = model.transcribe(tmp_path, fp16=False)  # fp16=False for CPU
        return result["text"].strip()
    finally:
        os.unlink(tmp_path)
