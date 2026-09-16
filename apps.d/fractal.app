# Fractal Rig — projector visualiser: master (param engine + web UI) and the GLES renderer (STUDIO - Fractal Rig)
NAME="fractal"
LABEL="Fractal Rig"
REPO="https://github.com/sonorltd/sonor-fractal-rig.git"
DIR="fractal-rig"

INSTALL="bash setup/install.sh master"        # builds the renderer, master venv, both units
UNITS="fractal-master"

# Test-rig differences from a dedicated master Pi:
#  1. Web UI on 8081, not 8080 — the C-Bus daemon serves its bundled app on a fixed 8080.
#  2. The renderer is NOT run as the KMSDRM system service (the desktop owns the GPU on a
#     Pi that also drives a touch-panel kiosk). It runs inside the desktop session on the
#     second HDMI output instead — see SESSION. post_install disables the shipped renderer unit.
DROPIN="[Service]
EnvironmentFile=-/etc/sonor-rig/fractal.env
ExecStart=
ExecStart=$APP_PATH/master/.venv/bin/python $APP_PATH/master/master.py --quiet --port \${WEB_PORT} \$ARGS"
ENV_DEFAULT="WEB_PORT=8081
# extra master args, e.g. --audio (live audio) or --no-prodj
ARGS="
post_install() { systemctl disable --now fractal-renderer.service 2>/dev/null || true; }

URL="http://localhost:${WEB_PORT:-8081}/?perf=1"
HEALTH="http://localhost:${WEB_PORT:-8081}/"
SESSION="renderer/fractal --display ${RENDER_DISPLAY:-1} ${RENDER_ARGS:-}"

PORTS="${WEB_PORT:-8081}/tcp web (8080 on a dedicated Pi) · 5005/udp FRX1 multicast 239.255.42.1 · 9000/udp OSC · 50000-50002/udp Pro DJ Link · out→4048/udp 5568/udp 6454/udp LED strip"
NOTES="Renderer shows on HDMI-A-2 (RENDER_DISPLAY in /etc/sonor-rig/rig.env). Pixel Conductor's beat clock follows this master's multicast automatically."
