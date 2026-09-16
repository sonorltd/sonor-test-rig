# STUDIO - Test Rig · `sonor-rig`

**One Pi 5, every Sonor project, switchable.** A thin layer over each project's *own* dedicated-Pi
installer so a single bench Pi can host Pixel Conductor, the Fractal Rig, the C-Bus daemon and the
eDIN+ bridge side by side — all running at once — with the 7" touch panel and the HDMI output pointed
at whichever one is being worked on.

Field Pis stay **one app per Pi** and use each project's installer directly; they never see this repo.

```
sonor-rig list                  what's installed / running / healthy, ▶ = on the panel
sonor-rig install pixel         git clone + the project's own installer (idempotent; `all` for everything)
sonor-rig use fractal           panel → Fractal perform UI, renderer on the second HDMI; nothing else stops
sonor-rig only cbus             use cbus AND stop the other apps' services
sonor-rig all                   start every installed app again
sonor-rig start|stop|restart|enable|disable|logs <app>
sonor-rig update all            git pull + re-run every installer
sonor-rig ports                 declared ports · what's listening · clashes
sonor-rig doctor                throttling, temp, displays, FTDI adapters, session loop
sonor-rig add <name>            scaffold apps.d/<name>.app for the next project
```

## How it works

```
apps.d/<name>.app        one file per project: REPO, INSTALL (its own installer), UNITS, URL, PORTS …
sonor-rig                the CLI (symlinked to /usr/local/bin) — clones, installs, enables, switches
session/…session.sh      runs in the desktop login: Chromium kiosk on the front app's URL + its
                         display program (the Fractal renderer); watches /etc/sonor-rig/current
/etc/sonor-rig/          rig.env (panel size, renderer display) · <app>.env (per-app ARGS, ports) · current
~/sonor/<app>/           the checkouts, exactly as a dedicated Pi would have them
```

`sonor-rig use X` writes one file; the session loop swaps the kiosk and the display program within
two seconds. Every project's services keep running unless you say `only`. Per-app systemd drop-ins in
`/etc/systemd/system/<unit>.service.d/sonor-rig.conf` are the *only* rig-specific change to how a
project runs (the Fractal web UI on 8081, `$ARGS` from an env file) — the project repos are untouched.

## Apps on the rig today

| app | project | installer used | panel shows | rig-specific |
|---|---|---|---|---|
| `pixel` | STUDIO - Pixel Conductor | `setup/install-pi.sh` | Perform mode `:8760/?mode=perform` | `ARGS` env (`--simulate` with no nodes) |
| `fractal` | STUDIO - Fractal Rig | `setup/install.sh master` | Perform UI `:8081/?perf=1` + renderer on HDMI-A-2 | web port 8081; renderer runs in the desktop session, not as the KMSDRM unit |
| `cbus` | APP - C-Bus (`daemon/`) | venv from `requirements-232.txt` (repo has no script) | bundled app `http://<ip>:8080` | rig-written unit (shipped one hard-codes `/home/pi`); simulator by default |
| `edin` | sonor-edin-cbus-bridge | `deploy/install.sh` | headless (`sonor-rig logs edin`) | simulator by default; C-Gate not installed |

Docs: **[docs/BENCH.md](docs/BENCH.md)** (parts, image, first boot, two screens, private repo) ·
**[docs/PORTS.md](docs/PORTS.md)** (the port table and the one 8080 clash).

## Adding the next project

`sonor-rig add hub`, fill in `apps.d/hub.app` (see `apps.d/TEMPLATE.app` — REPO, INSTALL, UNITS, URL,
PORTS), `bash tests/test_rig.sh`, commit. The tests fail on a listening-port clash, an unexpanded
`$APP_PATH` in systemd text, or a bash `${x:-y}` default leaking into a unit file.

## Tests

`bash tests/test_rig.sh` — no Pi, no root, no network: syntax + shellcheck, every app file sources
cleanly, port-clash check, and the CLI's read-only commands against a temp copy. 17 checks.
