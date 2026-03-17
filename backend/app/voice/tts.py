import asyncio
import base64
import io

import edge_tts

_VOICE = "en-US-JennyNeural"   # natural-sounding neural voice


async def _synthesise_async(text: str) -> bytes:
    communicate = edge_tts.Communicate(text, _VOICE)
    buf = io.BytesIO()
    async for chunk in communicate.stream():
        if chunk["type"] == "audio":
            buf.write(chunk["data"])
    return buf.getvalue()


def synthesise_speech(text: str) -> str:
    """
    Convert text to speech using Microsoft Edge TTS (en-US-JennyNeural).
    Returns base64-encoded MP3 audio string, or None on failure.
    """
    try:
        audio_bytes = asyncio.run(_synthesise_async(text))
        if not audio_bytes:
            return None
        return base64.b64encode(audio_bytes).decode("utf-8")
    except Exception as e:
        print(f"[TTS] edge-tts failed: {e}")
        return None
