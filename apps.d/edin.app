# eDIN+ ↔ C-Bus bridge — headless (sonor-edin-cbus-bridge). Needs C-Gate for a real network.
NAME="edin"
LABEL="eDIN+ C-Bus bridge"
REPO="https://github.com/sonorltd/sonor-edin-cbus-bridge.git"
DIR="edin-cbus-bridge"

INSTALL="bash deploy/install.sh"              # installs to /opt/sonor-edin-cbus-bridge, config in /etc/sonor-edin-cbus-bridge
UNITS="sonor-edin-cbus-bridge"

# Bench default = the built-in simulator (no C-Gate, no NPU). Real site: set ARGS to --config … in the env.
DROPIN="[Service]
EnvironmentFile=-/etc/sonor-rig/edin.env
ExecStart=
ExecStart=/opt/sonor-edin-cbus-bridge/.venv/bin/python -m bridge \$ARGS"
ENV_DEFAULT="# simulator (built-in fake NPU 8826 + fake C-Gate 28023/28025). Real:
#   ARGS=--config /etc/sonor-edin-cbus-bridge/config.yaml --log INFO
ARGS=--simulate --log INFO"

URL=""                                        # headless — nothing to show on the panel
HEALTH=""
PORTS="none listening · out→26/tcp eDIN+ NPU · out→20023/tcp 20025/tcp C-Gate · sim: 8826/tcp 28023/tcp 28025/tcp"
ICON="edin"
COLOR="#f5d05c"
NOTES="Watch it with: sonor-rig logs edin. C-Gate (Java) is not installed by the rig — see the bridge README."
