# Ports on the test rig

One Pi, several daemons — this table is the rule that keeps them from treading on each other.
`sonor-rig ports` prints the declared list, what is actually listening, and any clash.

| app | listens | talks out to | notes |
|---|---|---|---|
| **Pixel Conductor** `pixel` | 8760/tcp web + WS · 4980/tcp Control4 · 9100/udp OSC | 4048/udp DDP → WLED nodes · WLED `/json` over 80/tcp | joins the FRX1 multicast group as a listener |
| **Fractal Rig master** `fractal` | **8081/tcp** web (8080 on a dedicated Pi) · 5005/udp FRX1 multicast `239.255.42.1` · 9000/udp OSC · 50000–50002/udp Pro DJ Link | 4048/udp DDP · 5568/udp sACN · 6454/udp Art-Net (optional LED output) | renderer runs in the desktop session, no ports |
| **C-Bus daemon** `cbus` | 8765/tcp WebSocket (app ↔ daemon) · **8080/tcp** bundled web app (fixed in `start_webapp_server`) | 10001/tcp to a 5500CN2 · or `/dev/ttyUSB0` to a 5500PC | the bundled app only auto-connects when served from `http://<ip>:8080` |
| **eDIN+ bridge** `edin` | nothing (simulator: 8826 / 28023 / 28025 tcp) | 26/tcp eDIN+ NPU · 20023 + 20025/tcp C-Gate | headless |
| sonor-rig itself | nothing | — | the panel is a local Chromium kiosk |

## The one clash, and the fix

The **Fractal Rig master** and the **C-Bus daemon** both default to **8080/tcp** for their web UI.
The C-Bus daemon's port is hard-coded (and its bundled app keys off `location.port === '8080'`), the
Fractal master's is a flag (`--port`). So on the rig the Fractal master moves to **8081** via the
systemd drop-in that `apps.d/fractal.app` writes (`WEB_PORT` in `/etc/sonor-rig/fractal.env`).
Dedicated field Pis keep 8080 — nothing in either project changed.

## Adding a project

Declare its ports in `PORTS=` in the app file using `port/proto` tokens; outbound ones after `out→`.
`tests/test_rig.sh` fails if two apps declare the same listening port, so the clash is caught before
a Pi is ever imaged.

## Multicast

Pixel Conductor and the Fractal master both join `239.255.42.1:5005`. The master *sends*, the
conductor *listens*; two listeners on one host is fine (SO_REUSEADDR), and the loopback delivery
means the conductor's beat clock follows the master automatically on the rig without any config.
