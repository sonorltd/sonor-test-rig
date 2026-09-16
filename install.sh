#!/usr/bin/env bash
# sonor-rig bootstrap — turn a fresh Raspberry Pi OS (64-bit, WITH desktop) into the Sonor test rig.
#
#   git clone https://github.com/sonorltd/sonor-test-rig.git ~/sonor/test-rig
#   cd ~/sonor/test-rig
#   sudo bash install.sh                          # rig tooling + session loop only (then: sonor-rig install …)
#   sudo bash install.sh --apps pixel,fractal     # …and install those projects now
#   sudo bash install.sh --apps all --front pixel # everything, panel on Pixel Conductor
#   sudo bash install.sh --session-only           # just (re)install the desktop autostart bits
#
# Why "with desktop": the Fractal renderer and a Chromium kiosk can't share the GPU on Pi OS Lite
# (KMSDRM = one owner). Under the desktop compositor both are ordinary windows on two outputs.
# Idempotent — re-run any time.
set -euo pipefail
RIG_HOME="$(cd "$(dirname "$0")" && pwd)"
USER_NAME="${SUDO_USER:-$(whoami)}"; HOME_DIR="$(getent passwd "$USER_NAME" | cut -d: -f6)"
ETC=/etc/sonor-rig
APPS=""; FRONT=""; SESSION_ONLY=0
while [ $# -gt 0 ]; do case "$1" in
  --apps) APPS="$2"; shift 2;; --front) FRONT="$2"; shift 2;; --session-only) SESSION_ONLY=1; shift;;
  *) echo "unknown arg $1"; exit 1;; esac; done
[ "$(id -u)" -eq 0 ] || { echo "run with sudo"; exit 1; }

echo "== sonor-rig :: user=$USER_NAME rig=$RIG_HOME"

if [ "$SESSION_ONLY" = 0 ]; then
  echo "== apt"
  apt-get update -qq
  apt-get install -y -qq git curl jq python3-venv python3-pip build-essential unclutter wlr-randr \
      libportaudio2 >/dev/null 2>&1 || true
  command -v chromium >/dev/null || command -v chromium-browser >/dev/null || apt-get install -y -qq chromium 2>/dev/null || apt-get install -y -qq chromium-browser

  echo "== sonor-rig command"
  chmod +x "$RIG_HOME/sonor-rig" "$RIG_HOME/session/sonor-rig-session.sh"
  ln -sf "$RIG_HOME/sonor-rig" /usr/local/bin/sonor-rig

  echo "== $ETC"
  mkdir -p "$ETC"; chmod 755 "$ETC"
  [ -f "$ETC/rig.env" ] || cat > "$ETC/rig.env" <<EOF
# sonor-rig — bench-wide settings (sourced by sonor-rig and the session loop)
KIOSK_SIZE=1024,600          # the touch panel (ROADOM 7" = 1024x600)
RENDER_DISPLAY=1             # SDL display index for the Fractal renderer (0 = panel, 1 = second HDMI)
RENDER_ARGS=                 # extra renderer args, e.g. --window 1280x720 to test it on the panel itself
CHROME_EXTRA_FLAGS=
EOF
  chmod 644 "$ETC/rig.env"

  # the pi user gets to run sonor-rig without a password prompt (it's a bench, not a site)
  echo "$USER_NAME ALL=(ALL) NOPASSWD:SETENV: /usr/local/bin/sonor-rig, $RIG_HOME/sonor-rig" > /etc/sudoers.d/sonor-rig; chmod 440 /etc/sudoers.d/sonor-rig
  visudo -cf /etc/sudoers.d/sonor-rig >/dev/null || { rm -f /etc/sudoers.d/sonor-rig; echo "   (sudoers snippet rejected — removed; you'll be asked for a password by sonor-rig)"; }
fi

echo "== desktop session autostart (kiosk + front app's display program)"
SESSION="$RIG_HOME/session/sonor-rig-session.sh"
mkdir -p "$HOME_DIR/.config/autostart" "$HOME_DIR/.config/labwc"
cat > "$HOME_DIR/.config/autostart/sonor-rig-session.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=sonor-rig session
Exec=$SESSION
X-GNOME-Autostart-enabled=true
EOF
grep -q "sonor-rig-session" "$HOME_DIR/.config/labwc/autostart" 2>/dev/null || echo "$SESSION &  # sonor-rig" >> "$HOME_DIR/.config/labwc/autostart"
chown -R "$USER_NAME" "$HOME_DIR/.config/autostart" "$HOME_DIR/.config/labwc"
# boot straight to the desktop as this user, screen never blanks
command -v raspi-config >/dev/null && raspi-config nonint do_boot_behaviour B4 || true
grep -q consoleblank /boot/firmware/cmdline.txt 2>/dev/null || sed -i 's/$/ consoleblank=0/' /boot/firmware/cmdline.txt || true
mkdir -p /etc/xdg/autostart
printf '[Desktop Entry]\nType=Application\nName=sonor-rig no-blank\nExec=sh -c "xset s off; xset -dpms; xset s noblank"\n' > /etc/xdg/autostart/sonor-rig-noblank.desktop

if [ -n "$APPS" ]; then
  echo "== apps: $APPS"
  IFS=, read -ra LIST <<< "$APPS"
  RIG_ROOT="$HOME_DIR/sonor" SUDO_USER="$USER_NAME" "$RIG_HOME/sonor-rig" install "${LIST[@]}"
fi
if [ -n "$FRONT" ]; then RIG_ROOT="$HOME_DIR/sonor" SUDO_USER="$USER_NAME" "$RIG_HOME/sonor-rig" use "$FRONT"; fi

echo
echo "== done.  sonor-rig list · sonor-rig install <app|all> · sonor-rig use <app> · sonor-rig doctor"
echo "   Reboot (or log out/in) once so the panel session starts. Apps live in $HOME_DIR/sonor/"
