# apps.d/__NAME__.app — one Sonor project on the test rig. Plain bash, sourced by sonor-rig.
#
# Before this file is sourced, sonor-rig has already sourced /etc/sonor-rig/rig.env and
# /etc/sonor-rig/__NAME__.env, and set $RIG_USER, $RIG_ROOT, $RIG_IP, $APP_PATH ($RIG_ROOT/DIR).
# Anything meant for systemd (not bash) must be escaped: \$ARGS, \${WEB_PORT}.

NAME="__NAME__"                       # must equal the file name
LABEL="__NAME__"                      # human name
REPO="https://github.com/sonorltd/sonor-__NAME__.git"
BRANCH=""                             # default branch if empty
DIR="__NAME__"                        # checkout dir under $RIG_ROOT (default: NAME)

# The project's OWN dedicated-Pi installer, run as root from $APP_PATH (SUDO_USER is set to the
# rig user so installers that build a venv "as the invoking user" keep working). Idempotent please.
INSTALL="bash setup/install-pi.sh"

# systemd units the project installs (first one is the "main" unit the drop-in / UNIT_FILE target).
UNITS="sonor-__NAME__"

# Optional: a whole unit file to write as /etc/systemd/system/<first unit>.service — for projects
# whose shipped unit hard-codes /home/pi paths. Leave empty to use the project's own unit.
UNIT_FILE=""

# Optional: a systemd drop-in for the first unit (e.g. move a port, add an EnvironmentFile).
DROPIN=""

# Optional: first contents of /etc/sonor-rig/__NAME__.env (only written if the file doesn't exist).
ENV_DEFAULT=""

# Front-app bits. URL = what the touch panel shows when this is the front app ("" = headless).
URL="http://localhost:8000/"
HEALTH="http://localhost:8000/"       # 2xx/3xx = healthy ("" = no check)
# Optional: a program to run INSIDE the desktop session while this is the front app
# (relative to $APP_PATH; e.g. a renderer that owns the second HDMI output).
SESSION=""

PORTS="8000/tcp web"                  # "port/proto what · port/proto what · out→port/proto what"
NOTES=""                              # printed after install

# Optional hook, runs as root after the installer, before units are (re)started.
# post_install() { :; }
