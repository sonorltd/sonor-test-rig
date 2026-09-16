# STUDIO - Test Rig (v0.1.0)

> Current version: 0.1.0 · Repo: `sonor-test-rig` · No Pages (nothing to host — it's a Pi tool).
> Type: side-project / infra (STUDIO class). Not a product; never installed on a field Pi.

`sonor-rig` — one bench Pi 5 hosting every Sonor daemon project (Pixel Conductor, Fractal Rig, C-Bus daemon,
eDIN+ bridge, …) side by side, with the touch panel / HDMI switched between them. **Read `README.md`,
`docs/BENCH.md` and `docs/PORTS.md` first.**

## Spine
- Spine version: n/a — **exempt**. Bash + systemd, no browser app, no Supabase. Registered in
  `workspace-apps.tsv` as `type=infra, isolation=island-ok`.

## Shared seams consumed
- None at runtime. It *drives* the sibling projects through their own installers and systemd units:
  `STUDIO - Pixel Conductor/setup/install-pi.sh`, `STUDIO - Fractal Rig/setup/install.sh`,
  `APP - C-Bus/daemon/` (venv only — no installer there), `sonor-edin-cbus-bridge/deploy/install.sh`.
  If one of those changes its unit name, path layout or flags, the matching `apps.d/<app>.app` must follow.

## Data flows
- Reads: GitHub (clones), each app's health URL (curl), `/etc/sonor-rig/*.env`.
- Writes: `/etc/sonor-rig/` (current, kiosk.url, env files), `/etc/systemd/system/<unit>.service{,.d/sonor-rig.conf}`,
  `/usr/local/bin/sonor-rig`, `/etc/sudoers.d/sonor-rig`, the user's labwc/XDG autostart.
- No customer data. No network services of its own.

## Single sources of truth
- `apps.d/<name>.app` = everything the rig knows about a project (repo, installer, units, URL, ports).
  Adding a project = adding one file. The `PORTS=` line is what `sonor-rig ports` and the tests check.
- `docs/PORTS.md` = the port table across projects; the **only cross-project clash** (Fractal master vs C-Bus
  daemon, both 8080) is resolved here by moving the Fractal master to 8081 *on the rig only*.

## Rules for this project
- **Never patch a project to suit the rig.** Rig-specific behaviour goes in a systemd drop-in (`DROPIN=`), a
  rig-written unit (`UNIT_FILE=`) or an env file (`ENV_DEFAULT=`) — the checkout under `~/sonor/<app>` must
  stay a clean clone so `sonor-rig update` is a fast-forward.
- **Every app must be simulator-safe by default** (`ARGS=--simulate` or equivalent) so a bare Pi with no
  hardware comes up green; real hardware is an env-file edit, not a code change.
- **Systemd text is not bash.** In `DROPIN=` / `UNIT_FILE=` escape `\$ARGS`, `\${WEB_PORT}`; never use
  `${x:-default}` there (the tests catch it). `$APP_PATH` / `$RIG_USER` *are* expanded at source time.
- The desktop session owns the GPU: nothing on the rig may run SDL KMSDRM as a system unit. Display programs
  go in `SESSION=` and run inside the login session on `RENDER_DISPLAY`.
- `bash tests/test_rig.sh` must stay green (17 checks, no Pi needed). Untested on real hardware as of v0.1.0 —
  the first bench build gets a patch bump with whatever the two-screen layout needs.
- Version lives in `sonor-rig` `RIG_VERSION` + this banner. Commit format `v{X.Y.Z}: …`.

## Feature timeline
- 2026-09-16 v0.1.0 — first cut (Bryn: "a version that works too for hosting multiple on the test rig we can
  easily add to as things develop"): `sonor-rig` CLI (list/status, install/update via each project's own
  installer, use/only/all, start/stop/restart/enable/disable/logs, ports with live listen + clash check, doctor,
  add scaffold), `apps.d/` definitions for pixel / fractal / cbus / edin with simulator-safe defaults and
  rig-only drop-ins (Fractal web → 8081, renderer in-session on HDMI-A-2, rig-written C-Bus unit, eDIN sim),
  desktop session loop (Chromium kiosk + front app's display program, watches `/etc/sonor-rig/current`,
  restarts crashed children, waiting page), `install.sh` bootstrap (apt, symlink, sudoers, autostart,
  auto-login, no-blank, `--apps`/`--front`), docs (BENCH, PORTS), 17 bash tests.

## Pending / next (see IDEAS.md)
- First real bench build on the Pi 5: confirm Chromium lands on HDMI-A-1 and the renderer on HDMI-A-2 under labwc.
- `hub` / `dj-admin` app files once those have a daemon worth running on the bench.
