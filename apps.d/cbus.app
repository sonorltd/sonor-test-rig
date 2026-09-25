# Sonor C-Bus daemon — Clipsal Wiser replacement + bundled web app (APP - C-Bus, daemon/)
NAME="cbus"
LABEL="C-Bus daemon"
REPO="https://github.com/sonorltd/sonor-cbus.git"    # PRIVATE — see NOTES
DIR="cbus"

# The repo has no installer script (PI-SETUP.md is manual): build the venv with the full 232 set
# (websockets, pyserial, libcbus) so the same install works for --simulate and a real 5500PC.
INSTALL="sudo -u \$RIG_USER -H bash -c 'cd daemon && python3 -m venv .venv && .venv/bin/pip install -q --disable-pip-version-check -r requirements-232.txt'"
UNITS="sonor-cbus"

# The shipped unit hard-codes /home/pi/sonor-cbus — write our own with the rig path + \$ARGS.
UNIT_FILE="[Unit]
Description=Sonor C-Bus daemon (test rig)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$RIG_USER
WorkingDirectory=$APP_PATH/daemon
EnvironmentFile=-/etc/sonor-rig/cbus.env
ExecStart=$APP_PATH/daemon/.venv/bin/python sonor_cbus_daemon.py \$ARGS
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target"
ENV_DEFAULT="# simulator by default. Real PCI on the bench:
#   ARGS=--serial /dev/ttyUSB0 --port 8765 --auth        (5500PC on FTDI)
#   ARGS=--tcp 192.168.1.50:10001 --port 8765 --auth      (5500CN2)
ARGS=--simulate --port 8765"

# Use the LAN IP, not localhost: the bundled app only auto-connects to the daemon's websocket
# when it is served from http://<controller-ip>:8080.
URL="http://$RIG_IP:8080/"
HEALTH="http://localhost:8080/"
PORTS="8765/tcp websocket (app ↔ daemon) · 8080/tcp bundled web app (fixed in the daemon) · in: /dev/ttyUSB0 or out→10001/tcp PCI"
ICON="cbus"
COLOR="#4bb9d3"
NOTES="Private repo: 'gh auth login' on the rig first, or copy it over:  scp -r 'APP - C-Bus' $RIG_USER@$(hostname).local:$APP_PATH"
