#!/usr/bin/env bash
# sonor-rig session loop — the desktop half of the test rig. Started at login (labwc / XDG autostart),
# runs as the desktop user, never as root.
#
#  • keeps a Chromium kiosk on the touch panel pointed at the FRONT app's URL
#  • runs the front app's SESSION program (e.g. the Fractal renderer on the second HDMI output)
#  • watches /etc/sonor-rig/current — `sonor-rig use <app>` just rewrites that file and this loop
#    swaps everything over within ~2 s. Crashed children are restarted; nothing ever leaves a blank panel.
set -u
ETC=/etc/sonor-rig
SELF="$(readlink -f "${BASH_SOURCE[0]}")"; RIG_HOME="$(cd "$(dirname "$SELF")/.." && pwd)"
APPS_D="$RIG_HOME/apps.d"
RIG_USER="$(id -un)"; RIG_ROOT="${RIG_ROOT:-$HOME/sonor}"
RIG_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"; RIG_IP="${RIG_IP:-localhost}"
LOG="$HOME/.cache/sonor-rig-session.log"; mkdir -p "$(dirname "$LOG")"
log() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" >> "$LOG"; }

CHROME="$(command -v chromium || command -v chromium-browser || true)"
[ -n "$CHROME" ] || { log "no chromium — nothing to show"; exit 1; }
# shellcheck disable=SC1091
[ -f "$ETC/rig.env" ] && . "$ETC/rig.env"
FLAGS="--kiosk --noerrdialogs --disable-infobars --disable-session-crashed-bubble --disable-translate
 --overscroll-history-navigation=0 --touch-events=enabled --enable-features=OverlayScrollbar
 --check-for-update-interval=31536000 --autoplay-policy=no-user-gesture-required
 --window-size=${KIOSK_SIZE:-1024,600} --window-position=0,0 ${CHROME_EXTRA_FLAGS:-}"

# keep the panel awake (X11 + Wayland variants; harmless where absent)
xset s off 2>/dev/null; xset -dpms 2>/dev/null; xset s noblank 2>/dev/null
command -v unclutter >/dev/null && { pgrep -x unclutter >/dev/null || unclutter -idle 3 -root & }

CHROME_PID=""; SESSION_PID=""
stop_children() {
  [ -n "$SESSION_PID" ] && kill "$SESSION_PID" 2>/dev/null; [ -n "$CHROME_PID" ] && kill "$CHROME_PID" 2>/dev/null
  sleep 0.5; [ -n "$SESSION_PID" ] && kill -9 "$SESSION_PID" 2>/dev/null; [ -n "$CHROME_PID" ] && kill -9 "$CHROME_PID" 2>/dev/null
  pkill -f -- "--app=$URL" 2>/dev/null; CHROME_PID=""; SESSION_PID=""
}
trap 'stop_children; exit 0' INT TERM

load_front() {   # sets NAME URL SESSION APP_PATH from the current front app ("" if none)
  NAME="$(cat "$ETC/current" 2>/dev/null || true)"; URL=""; SESSION=""; APP_PATH=""
  [ -n "$NAME" ] && [ -f "$APPS_D/$NAME.app" ] || { NAME=""; return; }
  # shellcheck disable=SC1090
  [ -f "$ETC/$NAME.env" ] && . "$ETC/$NAME.env"
  DIR="$NAME"; APP_PATH="$RIG_ROOT/$NAME"
  # shellcheck disable=SC1090
  . "$APPS_D/$NAME.app"
  APP_PATH="$RIG_ROOT/${DIR:-$NAME}"
}
start_chrome()  { [ -n "$URL" ] || return; log "kiosk → $URL"; "$CHROME" $FLAGS --app="$URL" "$URL" >/dev/null 2>&1 & CHROME_PID=$!; }
start_session() { [ -n "$SESSION" ] || return; log "session → $SESSION (in $APP_PATH)"; ( cd "$APP_PATH" && exec bash -c "$SESSION" ) >>"$LOG" 2>&1 & SESSION_PID=$!; }

stamp_of() { stat -c %Y "$ETC/current" 2>/dev/null || echo 0; }

while true; do
  load_front; STAMP="$(stamp_of)"
  if [ -z "$NAME" ]; then
    log "no front app yet (sonor-rig use <app>) — showing the rig page"
    URL="file://$RIG_HOME/session/waiting.html"; start_chrome
  else
    start_chrome; start_session
  fi
  while [ "$(stamp_of)" = "$STAMP" ]; do
    sleep 2
    if [ -n "$CHROME_PID" ] && ! kill -0 "$CHROME_PID" 2>/dev/null; then log "chromium died — restarting"; sleep 2; start_chrome; fi
    if [ -n "$SESSION_PID" ] && ! kill -0 "$SESSION_PID" 2>/dev/null; then log "session program died — restarting in 3 s"; sleep 3; start_session; fi
  done
  log "front app changed → $(cat "$ETC/current" 2>/dev/null)"; stop_children
done
