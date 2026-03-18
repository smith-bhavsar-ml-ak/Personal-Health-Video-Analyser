# Root-level Dockerfile — used by Railway (build context = repo root).
# docker-compose uses backend/Dockerfile directly with context = ./backend.

FROM python:3.11-slim

WORKDIR /app

# System deps for OpenCV + MediaPipe
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libespeak1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install Python deps first (layer cached unless requirements.txt changes)
COPY backend/requirements.txt .
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

# Copy backend source
COPY backend/ .

RUN mkdir -p /app/data

EXPOSE 8000

# Railway injects $PORT — bind to it at runtime
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
