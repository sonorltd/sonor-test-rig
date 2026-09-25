#!/usr/bin/env python3
"""sonor-rig launcher — the touch-panel home screen of the test rig.

A tiny stdlib HTTP server (no pip deps) that the session loop runs as the desktop user on
127.0.0.1:8700. The kiosk points at it; it shows one big tile per app in apps.d, with live
status, and a tap makes that app the front app (`sudo -n sonor-rig use <app>` — the installer's
sudoers snippet allows that without a password). The chosen app is then shown full-screen inside
the launcher (an iframe) with a small ⌂ tab to come back to the grid, so the apps and the Fractal
renderer keep running while you browse.

    launcher.py                 serve on 127.0.0.1:8700 (env LAUNCHER_PORT to change)
    launcher.py --dump          print the /api/apps JSON once and exit (used by the tests)

Bench-only: field Pis never see this file.
"""
import json, os, subprocess, sys, time, urllib.request, urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.realpath(__file__))
RIG_HOME = os.path.realpath(os.path.join(HERE, ".."))
APPS_D = os.path.join(RIG_HOME, "apps.d")
ETC = "/etc/sonor-rig"
PORT = int(os.environ.get("LAUNCHER_PORT", "8700"))
RIG_USER = os.environ.get("RIG_USER") or os.environ.get("USER") or "pi"
RIG_ROOT = os.environ.get("RIG_ROOT") or os.path.expanduser("~/sonor")
SONOR_RIG = os.environ.get("SONOR_RIG_BIN") or os.path.join(RIG_HOME, "sonor-rig")

FIELDS = ["NAME", "LABEL", "URL", "HEALTH", "UNITS", "DIR", "ICON", "COLOR", "NOTES"]


def rig_ip():
    try:
        out = subprocess.run(["hostname", "-I"], capture_output=True, text=True, timeout=3).stdout.split()
        return out[0] if out else "localhost"
    except Exception:
        return "localhost"


def read_app(name, ip):
    """Source the .app file exactly the way sonor-rig does (twice, so $APP_PATH uses DIR) and return its fields."""
    script = f"""
set +e
ETC={json.dumps(ETC)}; RIG_USER={json.dumps(RIG_USER)}; RIG_ROOT={json.dumps(RIG_ROOT)}; RIG_IP={json.dumps(ip)}
[ -f "$ETC/rig.env" ] && . "$ETC/rig.env"
[ -f "$ETC/{name}.env" ] && . "$ETC/{name}.env"
NAME=""; LABEL=""; URL=""; HEALTH=""; UNITS=""; DIR=""; ICON=""; COLOR=""; NOTES=""
DIR={json.dumps(name)}; APP_PATH="$RIG_ROOT/{name}"
. {json.dumps(os.path.join(APPS_D, name + '.app'))}
DIR="${{DIR:-{name}}}"; APP_PATH="$RIG_ROOT/$DIR"
. {json.dumps(os.path.join(APPS_D, name + '.app'))}
for k in {' '.join(FIELDS)}; do printf '%s\\t%s\\n' "$k" "${{!k}}"; done
"""
    try:
        out = subprocess.run(["bash", "-c", script], capture_output=True, text=True, timeout=5).stdout
    except Exception:
        return None
    d = {k: "" for k in FIELDS}
    for line in out.splitlines():
        if "\t" in line:
            k, v = line.split("\t", 1)
            d[k] = v
    return d if d["NAME"] == name else None


def unit_state(units):
    first = (units or "").split()
    if not first:
        return ""
    try:
        r = subprocess.run(["systemctl", "is-active", first[0]], capture_output=True, text=True, timeout=3)
        return r.stdout.strip() or "unknown"
    except Exception:
        return "unknown"


def healthy(url):
    if not url:
        return None
    try:
        with urllib.request.urlopen(url, timeout=1.5) as r:
            return 200 <= r.status < 400
    except urllib.error.HTTPError as e:
        return 200 <= e.code < 400
    except Exception:
        return False


def current():
    try:
        return open(os.path.join(ETC, "current")).read().strip()
    except Exception:
        return ""


def list_apps():
    ip = rig_ip()
    names = sorted(f[:-4] for f in os.listdir(APPS_D) if f.endswith(".app") and f != "TEMPLATE.app") if os.path.isdir(APPS_D) else []
    front = current()
    apps = []
    for n in names:
        a = read_app(n, ip)
        if not a:
            continue
        path = os.path.join(RIG_ROOT, a["DIR"] or n)
        installed = os.path.isdir(path)
        state = unit_state(a["UNITS"]) if installed else "not installed"
        apps.append(dict(
            name=n, label=a["LABEL"] or n, url=a["URL"], headless=not a["URL"], icon=a["ICON"] or n,
            color=a["COLOR"] or "", installed=installed, state=state,
            healthy=healthy(a["HEALTH"]) if installed and a["HEALTH"] else None,
            front=(n == front), notes=a["NOTES"],
        ))
    return dict(host=os.uname().nodename, ip=ip, front=front, time=time.strftime("%H:%M"), apps=apps)


def rig(*args):
    """Run sonor-rig as root (sudoers NOPASSWD from install.sh). Returns (ok, text)."""
    try:
        r = subprocess.run(["sudo", "-n", SONOR_RIG, *args], capture_output=True, text=True, timeout=60)
        return r.returncode == 0, (r.stdout + r.stderr).strip()
    except Exception as e:
        return False, str(e)


class H(BaseHTTPRequestHandler):
    server_version = "sonor-rig-launcher"

    def log_message(self, *a):   # quiet
        pass

    def _send(self, code, body, ctype="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode() if ctype == "application/json" else body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype + ("; charset=utf-8" if ctype.startswith("text/") else ""))
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        p = self.path.split("?")[0]
        if p in ("/", "/index.html"):
            with open(os.path.join(HERE, "launcher.html"), "rb") as f:
                return self._send(200, f.read(), "text/html")
        if p == "/api/apps":
            return self._send(200, list_apps())
        return self._send(404, {"error": "not found"})

    def do_POST(self):
        parts = [x for x in self.path.split("?")[0].split("/") if x]
        # /api/use/<app>   /api/units/<app>/<start|stop|restart>
        if len(parts) == 3 and parts[:2] == ["api", "use"]:
            ok, txt = rig("use", parts[2])
            return self._send(200 if ok else 500, {"ok": ok, "out": txt})
        if len(parts) == 4 and parts[:2] == ["api", "units"] and parts[3] in ("start", "stop", "restart"):
            ok, txt = rig(parts[3], parts[2])
            return self._send(200 if ok else 500, {"ok": ok, "out": txt})
        return self._send(404, {"error": "not found"})


def main():
    if "--dump" in sys.argv:
        print(json.dumps(list_apps(), indent=1))
        return
    srv = ThreadingHTTPServer(("127.0.0.1", PORT), H)
    print(f"sonor-rig launcher on http://127.0.0.1:{PORT}/  (apps.d: {APPS_D})", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
