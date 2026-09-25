#!/usr/bin/env bash
# sonor-rig tests — no Pi, no root, no network. Run: bash tests/test_rig.sh
#  1. every script parses (bash -n) and passes shellcheck if it's installed
#  2. every apps.d/*.app sources cleanly with the rig variables set, NAME matches, required keys present
#  3. no two apps declare the same LISTENING port (outbound "out→…" ignored)
#  4. the CLI runs read-only commands (list, ports, help, add) against a temp copy without root
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$*"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n' "$*"; }

echo "== syntax"
for f in "$ROOT/sonor-rig" "$ROOT/install.sh" "$ROOT/session/sonor-rig-session.sh" "$ROOT"/tests/*.sh; do
  bash -n "$f" && ok "bash -n $(basename "$f")" || bad "bash -n $(basename "$f")"
done
if command -v shellcheck >/dev/null; then
  shellcheck -S warning -e SC2086,SC2034,SC1090,SC1091,SC2015 "$ROOT/sonor-rig" "$ROOT/install.sh" "$ROOT/session/sonor-rig-session.sh" && ok "shellcheck" || bad "shellcheck"
else echo "  (shellcheck not installed — skipped)"; fi

echo "== app files"
export RIG_USER=pi RIG_ROOT=/home/pi/sonor RIG_IP=192.168.1.99
declare -A seen
for f in "$ROOT"/apps.d/*.app; do
  n="$(basename "$f" .app)"; [ "$n" = TEMPLATE ] && continue
  ( set -u; NAME= LABEL= REPO= DIR= INSTALL= UNITS= URL= HEALTH= PORTS= NOTES= SESSION= DROPIN= UNIT_FILE= ENV_DEFAULT=
    APP_PATH="$RIG_ROOT/$n"; . "$f"
    [ "$NAME" = "$n" ] || { echo "NAME '$NAME' != file '$n'"; exit 1; }
    [ -n "$LABEL" ] && [ -n "$INSTALL" ] && [ -n "$PORTS" ] || { echo "missing LABEL/INSTALL/PORTS"; exit 1; }
    [ -n "$UNITS" ] || [ -n "$SESSION" ] || { echo "neither UNITS nor SESSION"; exit 1; }
    [ -z "$URL" ] || [[ "$URL" =~ ^https?:// ]] || { echo "URL not http(s): $URL"; exit 1; }
    # systemd text must not contain unexpanded bash-isms and must have expanded $APP_PATH
    for blob in "$DROPIN" "$UNIT_FILE"; do
      [ -z "$blob" ] && continue
      grep -q '\${[A-Z_]*:-' <<<"$blob" && { echo "bash default syntax leaked into systemd text"; exit 1; }
      grep -q 'APP_PATH' <<<"$blob" && { echo "\$APP_PATH not expanded in systemd text"; exit 1; }
      grep -q 'ExecStart=' <<<"$blob" || { echo "systemd text has no ExecStart"; exit 1; }
    done
    # regression (2026-09-25): when DIR != NAME the drop-in must point at $RIG_ROOT/$DIR, not $RIG_ROOT/$NAME.
    # The CLI re-sources the .app once DIR is known; mirror that here and check the path that lands in systemd.
    DIR="${DIR:-$n}"; APP_PATH="$RIG_ROOT/$DIR"; . "$f"
    for blob in "$DROPIN" "$UNIT_FILE"; do
      [ -z "$blob" ] && continue
      grep -q "$RIG_ROOT/$DIR" <<<"$blob" || grep -q '/opt/' <<<"$blob" || { echo "systemd text does not use \$RIG_ROOT/$DIR"; exit 1; }
      [ "$DIR" = "$n" ] || ! grep -q "$RIG_ROOT/$n/" <<<"$blob" || { echo "systemd text still uses \$RIG_ROOT/$n (NAME) instead of $DIR"; exit 1; }
    done
  ) && ok "$n.app" || bad "$n.app"
done

echo "== port clashes"
clashes="$(for f in "$ROOT"/apps.d/*.app; do n="$(basename "$f" .app)"; [ "$n" = TEMPLATE ] && continue
  ( NAME= PORTS=; APP_PATH="$RIG_ROOT/$n"; . "$f" >/dev/null 2>&1; printf '%s\n' "$PORTS" | sed 's/out→[^·]*//g' | grep -oE '[0-9]{2,5}/(tcp|udp)' | sed "s/^/$n /" ); done \
  | awk '{p[$2]=p[$2]" "$1; c[$2]++} END{for(k in c) if(c[k]>1) print k":"p[k]}')"
[ -z "$clashes" ] && ok "no two apps listen on the same port" || bad "clash: $clashes"

echo "== cli (temp copy, no root)"
TMP="$(mktemp -d)"; cp -r "$ROOT"/. "$TMP/"; chmod +x "$TMP/sonor-rig"
"$TMP/sonor-rig" help | grep -q "sonor-rig use" && ok "help" || bad "help"
"$TMP/sonor-rig" version | grep -qE '^sonor-rig [0-9]+\.[0-9]+\.[0-9]+$' && ok "version" || bad "version"
out="$("$TMP/sonor-rig" list 2>&1)" && grep -q "pixel" <<<"$out" && ok "list shows apps" || bad "list: $out"
out="$("$TMP/sonor-rig" ports 2>&1)" && grep -q "declared ports" <<<"$out" && ok "ports" || bad "ports: $out"
"$TMP/sonor-rig" add zzz >/dev/null && [ -f "$TMP/apps.d/zzz.app" ] && grep -q 'NAME="zzz"' "$TMP/apps.d/zzz.app" && ok "add scaffolds" || bad "add"
out="$("$TMP/sonor-rig" list 2>&1)" && grep -q "zzz" <<<"$out" && ok "new app appears in list" || bad "new app in list"
"$TMP/sonor-rig" bogus >/dev/null 2>&1 && bad "unknown command should fail" || ok "unknown command fails"
rm -rf "$TMP"

echo; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
