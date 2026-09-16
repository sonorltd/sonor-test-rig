# Bench build — Pi 5 8GB test rig

Everything the studio projects need, on one Pi, switchable. Field Pis are still one-app-per-Pi
(they use each project's own installer and never see `sonor-rig`).

## Parts

- Raspberry Pi 5 **8GB** (4GB would do; 8 leaves room for projectM + NDI on the rig), **27 W USB-C PSU**
  (under-voltage throttles the GPU first — `sonor-rig doctor` shows the flag), active cooler, 32 GB+ A2 card.
- ROADOM 7" 1024×600 IPS touch panel → **HDMI-A-1** (micro-HDMI next to the USB-C) + USB for touch.
- Projector / TV for the Fractal renderer → **HDMI-A-2**.
- Gledopto / WLED nodes on the same LAN as the Pi (or `ARGS=--simulate` in `/etc/sonor-rig/pixel.env`).
- C-Bus: 5500PC + FTDI on USB (`/dev/ttyUSB0`) or a 5500CN2 on the LAN — or leave the simulator on.
- Optional: USB audio interface (Fractal master `--audio`, Pixel Conductor audio input), DJ gear on
  the LAN for Pro DJ Link.

## Image

Raspberry Pi Imager → **Raspberry Pi OS (64-bit) with desktop** (Bookworm or later, *not* Lite — see
`install.sh` header for why). In the Imager settings: hostname `sonor-rig`, user `pi`, SSH on, Wi-Fi if
no Ethernet, UK locale/timezone.

```bash
ssh pi@sonor-rig.local
sudo apt update && sudo apt full-upgrade -y && sudo apt install -y git
mkdir -p ~/sonor && git clone https://github.com/sonorltd/sonor-test-rig.git ~/sonor/test-rig
cd ~/sonor/test-rig
sudo bash install.sh --apps pixel,fractal --front pixel      # cbus needs the private repo (see below)
sudo reboot
```

After the reboot the panel boots into Pixel Conductor's Perform mode. Then:

```bash
sonor-rig list                 # what's installed / running / healthy
sonor-rig use fractal          # panel → Fractal Rig perform UI, renderer appears on HDMI-A-2
sonor-rig use pixel            # back again; both daemons keep running the whole time
sonor-rig only cbus            # stop the others (free the CPU / bus for one thing)
sonor-rig all                  # everything back on
sonor-rig logs fractal
sonor-rig update all           # git pull + re-run every installer
sonor-rig doctor
```

## The private C-Bus repo

`sonor-cbus` is private, so `sonor-rig install cbus` needs git auth on the Pi (`gh auth login`, or a
deploy key) — or just copy it from the Mac and the installer uses what it finds:

```bash
scp -r "$HOME/Code/Sonor/APP - C-Bus" pi@sonor-rig.local:~/sonor/cbus
ssh pi@sonor-rig.local sonor-rig install cbus
```

Simulator by default. Real PCI: edit `/etc/sonor-rig/cbus.env` (`ARGS=--serial /dev/ttyUSB0 --port 8765 --auth`)
then `sonor-rig restart cbus`.

## Two screens

The kiosk lands on the first output, the Fractal renderer goes fullscreen on SDL display
`RENDER_DISPLAY` (default 1 = the second HDMI). If they come up swapped, either swap the cables or set
`RENDER_DISPLAY=0` in `/etc/sonor-rig/rig.env` and `sonor-rig use fractal` again. To test the renderer
with only the panel attached: `RENDER_ARGS=--window 1024x600`.

Panel showing the wrong mode? Add `video=HDMI-A-1:1024x600@60` to `/boot/firmware/cmdline.txt`.

## Adding the next project

```bash
sonor-rig add hub          # scaffolds apps.d/hub.app from TEMPLATE.app
nano apps.d/hub.app        # REPO, INSTALL (its own installer), UNITS, URL, PORTS
bash tests/test_rig.sh     # lint + port-clash check
sonor-rig install hub
```

Commit the new `.app` file — that is the whole registration.
