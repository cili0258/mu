#!/usr/bin/env bash
set -euo pipefail

export DISPLAY=${DISPLAY:-:99}
export PORT=${PORT:-7860}

# Setup writable HOME and XDG dirs (HF Spaces may run as non-root)
HOME_DIR="${HOME:-/tmp/lx-home}"
export HOME="$HOME_DIR"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME_DIR/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME_DIR/.cache}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$HOME_DIR/.runtime}"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"

XVFB_W=1280
XVFB_H=800
XVFB_D=24
Xvfb "$DISPLAY" -screen 0 "${XVFB_W}x${XVFB_H}x${XVFB_D}" -ac +extension RANDR &
XVFB_PID=$!

openbox-session &

x11vnc -display "$DISPLAY" -forever -shared -nopw -rfbport 5900 -listen 0.0.0.0 -quiet &
X11VNC_PID=$!

NOVNC_WEB=/usr/share/novnc
if [ ! -d "$NOVNC_WEB" ]; then
  NOVNC_WEB=$(python3 - <<'PY'
import os
cands=["/usr/share/novnc","/usr/local/share/novnc","/opt/novnc"]
for p in cands:
    if os.path.isdir(p):
        print(p); break
PY
)
fi

if [ -d "$NOVNC_WEB" ]; then
  websockify --web "$NOVNC_WEB" "$PORT" localhost:5900 &
  echo "noVNC files served from $NOVNC_WEB"
else
  echo "noVNC web root not found, starting raw websockify"
  websockify "$PORT" localhost:5900 &
fi

echo "Space is ready at: http://0.0.0.0:${PORT}/vnc.html?autoconnect=true&resize=remote"

export OZONE_PLATFORM=x11
export ELECTRON_ENABLE_GPU=0

if [ -f "/app/dist/main.js" ]; then
  echo "Launching Electron app..."
  npx --no-install electron --no-sandbox /app
else
  echo "dist/main.js not found, building app..."
  npm run build:main && npm run build:renderer && npm run build:renderer-lyric && npm run build:renderer-scripts
  npx --no-install electron --no-sandbox /app
fi

wait "$XVFB_PID" "$X11VNC_PID"