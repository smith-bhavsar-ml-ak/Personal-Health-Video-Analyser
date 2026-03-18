# ─── Stage 1: Build Flutter web ──────────────────────────────────────────────
# Uses the official Cirrus Labs Flutter image (pre-installed SDK, ~3 GB image).
# First build is slow (~10 min); subsequent builds reuse pub-cache layer.
FROM ghcr.io/cirruslabs/flutter:stable AS builder

# API_BASE: full backend URL passed at build time.
# Example: https://phva-backend.railway.app/api/v1
# When blank, the built app falls back to relative /api/v1 (same-origin nginx proxy).
ARG API_BASE=""

WORKDIR /app

# 1. Restore packages (layer cached unless pubspec.yaml changes)
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# 2. Copy source and build
COPY . .
RUN if [ -n "$API_BASE" ]; then \
      flutter build web --release --web-renderer canvaskit --dart-define=API_BASE="$API_BASE"; \
    else \
      flutter build web --release --web-renderer canvaskit; \
    fi

# ─── Stage 2: Nginx static server ────────────────────────────────────────────
FROM nginx:1.27-alpine

# Copy compiled web assets
COPY --from=builder /app/build/web /usr/share/nginx/html

# SPA routing config (required for GoRouter path-based URLs)
COPY docker/nginx-spa.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
