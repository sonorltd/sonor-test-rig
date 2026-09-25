# Pixel Conductor — multi-zone WLED pixel-strip engine (STUDIO - Pixel Conductor)
NAME="pixel"
LABEL="Pixel Conductor"
REPO="https://github.com/sonorltd/sonor-pixel-conductor.git"
DIR="pixel-conductor"

INSTALL="bash setup/install-pi.sh"            # the dedicated-Pi installer, unchanged
UNITS="pixel-conductor"

# Same ExecStart as the shipped unit + $ARGS from /etc/sonor-rig/pixel.env (e.g. --simulate on a
# bench with no WLED nodes).
DROPIN="[Service]
EnvironmentFile=-/etc/sonor-rig/pixel.env
ExecStart=
ExecStart=$APP_PATH/.venv/bin/python -m conductor --data $APP_PATH/data \$ARGS"
ENV_DEFAULT="# extra conductor args. No nodes on the bench?  ARGS=--simulate
ARGS="

URL="http://localhost:8760/?mode=perform"
HEALTH="http://localhost:8760/api/state"
PORTS="8760/tcp web+ws · 4980/tcp Control4 · 9100/udp OSC · out→4048/udp DDP to the WLED nodes"
ICON="pixel"
COLOR="#e67eb1"
NOTES="Full UI at http://$RIG_IP:8760 — the panel boots into Perform mode; tap Exit for the micro controls."
