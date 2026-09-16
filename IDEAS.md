# Test Rig — ideas / backlog

## Next (v0.2)
- [ ] **Bench pass on the Pi 5**: two-output layout under labwc (kiosk → HDMI-A-1, renderer → HDMI-A-2); if
  Chromium picks the wrong output, add a `wlr-randr` arrangement step to the session loop (`KIOSK_OUTPUT=HDMI-A-1`).
- [ ] **On-panel switcher**: a tiny local page (served by the session loop via `python3 -m http.server` on 8790)
  with one big button per app, so you can switch without SSH. `sonor-rig use` already only writes one file.
- [ ] **Per-app "bench profile"** — `sonor-rig use fractal --profile projector` selecting a different env file
  (e.g. renderer windowed on the panel vs fullscreen on the projector).
- [ ] `sonor-rig snapshot` — tar of `/etc/sonor-rig` + each app's `data/` so a bench setup can be restored.
- [ ] Hub / DJ Admin / Dashboard app files when any of them grows a daemon worth running here.

## Later
- [ ] Docker variant (`docker compose --profile pixel,fractal`) for a Mac/NUC "rig" — Pixel Conductor already
  ships a Dockerfile; the Fractal renderer would stay native.
- [ ] Health push to the Master Hub (a `rig` card showing which app is front + green/red per daemon).
- [ ] `sonor-rig image` — pi-gen recipe that bakes the rig into an SD image.

## Done
- v0.1.0 — CLI, app files (pixel / fractal / cbus / edin), session loop, bootstrap installer, docs, tests.
