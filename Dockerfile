# syntax=docker/dockerfile:1

FROM node:22-bookworm AS builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates python3 make g++ build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install deps first to leverage Docker layer caching
COPY package.json package-lock.json ./
COPY build-config ./build-config
COPY resources ./resources

RUN npm ci

# Copy the rest of the source code
COPY . .

# Build production bundles
RUN npm run build:main && npm run build:renderer && npm run build:renderer-lyric && npm run build:renderer-scripts

# ---------- Runtime image ----------
FROM node:22-bookworm-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive
# Install runtime deps for Electron + Xvfb + VNC + noVNC + window manager
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb x11vnc novnc websockify openbox \
    libgtk-3-0 libnss3 libxss1 libasound2 libxtst6 \
    libx11-xcb1 libxcomposite1 libxrandr2 libxdamage1 libxshmfence1 libdrm2 libgbm1 libxcursor1 libxfixes3 \
    libpango-1.0-0 libcairo2 libxkbcommon0 libx11-6 libxext6 \
    libegl1 libgles2 libgl1 \
    fonts-noto fonts-noto-cjk fonts-liberation \
    curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV APP_HOME=/app
WORKDIR ${APP_HOME}

# Copy built app and dependencies from builder
COPY --from=builder /app ${APP_HOME}

# Add start script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh && sed -i 's/\r$//' /app/start.sh

# Environment for Electron in container
ENV DISPLAY=:99 \
    ELECTRON_DISABLE_SANDBOX=1 \
    ELECTRON_ENABLE_LOGGING=1 \
    ELECTRON_IS_DEV=0 \
    LIBGL_ALWAYS_SOFTWARE=1 \
    PORT=7860

EXPOSE 7860

CMD ["/bin/bash", "/app/start.sh"]