#!/usr/bin/env bash
#
# remmina-docker.sh — pull and launch the clipboard-fixed Remmina container.
#
# Pulls the image repo (kuppusamy433/remmina-docker) and runs Remmina against
# your host X server, keeping your Remmina config on the host. Validates the
# environment first (OS, display, Docker) and fails with a clear message.
#
# Usage:
#   ./remmina-docker.sh              launch Remmina
#   ./remmina-docker.sh --check      run all validations only, don't launch
#   ./remmina-docker.sh --help       show this help
#   IMAGE=other/image:tag ./remmina-docker.sh     use a different image
#   PULL=always ./remmina-docker.sh               re-pull even if present
#   any extra args are passed through to remmina (e.g. --version)
#
set -euo pipefail

IMAGE="${IMAGE:-kuppusamy433/remmina-docker:24.04}"
export DOCKER_HOST="${DOCKER_HOST:-unix:///var/run/docker.sock}"
CONTAINER_NAME="remmina-docker"

# ---------- pretty output ----------
if [ -t 1 ]; then C_ERR=$'\033[31m'; C_OK=$'\033[32m'; C_INF=$'\033[36m'; C_RST=$'\033[0m'
else C_ERR=; C_OK=; C_INF=; C_RST=; fi
info() { printf '%s[remmina-docker]%s %s\n' "$C_INF" "$C_RST" "$*"; }
ok()   { printf '%s[ok]%s %s\n'  "$C_OK"  "$C_RST" "$*"; }
err()  { printf '%s[error]%s %s\n' "$C_ERR" "$C_RST" "$*" >&2; }
die()  { err "$*"; exit 1; }

case "${1:-}" in
  --help|-h) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
CHECK_ONLY=0; [ "${1:-}" = "--check" ] && { CHECK_ONLY=1; shift; }

# ---------- 1. OS ----------
OS="$(uname -s)"
if [ -r /etc/os-release ]; then . /etc/os-release; OS_DESC="${PRETTY_NAME:-$OS}"; else OS_DESC="$OS"; fi
info "Host OS: ${OS_DESC} (kernel $(uname -r), arch $(uname -m))"
[ "$OS" = "Linux" ] || die "This launcher requires Linux with an X server. Detected '$OS'. On macOS/Windows run an X server (XQuartz/VcXsrv) and adapt manually."
ok "Operating system is Linux"

# ---------- 2. architecture (image is amd64) ----------
ARCH="$(uname -m)"
if [ "$ARCH" != "x86_64" ]; then
  err "Image is built for x86_64 but host is '$ARCH' — it may fail to run. Continuing anyway."
else
  ok "Architecture is x86_64"
fi

# ---------- 3. graphical session / DISPLAY ----------
if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ]; then
  die "Wayland session without XWayland (no DISPLAY). Start an X11 session or enable XWayland."
fi
[ -n "${DISPLAY:-}" ] || die "DISPLAY is not set — no graphical X session detected. Run this from your desktop session."
[ -n "${WAYLAND_DISPLAY:-}" ] && info "Wayland detected; using XWayland via DISPLAY=$DISPLAY"
ok "DISPLAY is set ($DISPLAY)"

# ---------- 4. X11 socket ----------
[ -d /tmp/.X11-unix ] || die "/tmp/.X11-unix not found — no X server socket to share with the container."
ok "X11 socket present (/tmp/.X11-unix)"

# ---------- 5. docker client ----------
command -v docker >/dev/null 2>&1 || die "docker not found. Install Docker Engine/Desktop first."
ok "docker client found ($(docker --version 2>/dev/null | cut -d, -f1))"

# ---------- 6. docker daemon ----------
docker info >/dev/null 2>&1 || die "Cannot reach the Docker daemon at ${DOCKER_HOST}. Is Docker running and is your user in the 'docker' group? (test with: docker info)"
ok "Docker daemon reachable"

# ---------- 7. xhost (optional but recommended) ----------
if command -v xhost >/dev/null 2>&1; then ok "xhost available"
else err "xhost not installed (package x11-xserver-utils). The window may fail to open; continuing."; fi

if [ "$CHECK_ONLY" = "1" ]; then ok "All checks passed. (--check: not launching)"; exit 0; fi

# ---------- 8. pull image repo ----------
if [ "${PULL:-ifmissing}" = "always" ] || ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  info "Pulling image ${IMAGE} ..."
  docker pull "$IMAGE" || die "Failed to pull ${IMAGE}. Check the name/tag and your network."
  ok "Image pulled"
else
  ok "Image already present locally (${IMAGE}); set PULL=always to refresh"
fi

# ---------- 9. grant local X access ----------
if command -v xhost >/dev/null 2>&1; then xhost +local: >/dev/null 2>&1 || err "xhost +local: failed; continuing"; fi

# ---------- 10. host config dirs (profiles persist here; nothing baked in image) ----------
mkdir -p "$HOME/.config/remmina" "$HOME/.local/share/remmina"

# ---------- 11. run ----------
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
info "Launching Remmina ..."
exec docker run --rm -it \
    --name "$CONTAINER_NAME" \
    --user "$(id -u):$(id -g)" \
    -e DISPLAY="$DISPLAY" \
    -e HOME=/home/remmina \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v "$HOME/.config/remmina":/home/remmina/.config/remmina \
    -v "$HOME/.local/share/remmina":/home/remmina/.local/share/remmina \
    "$IMAGE" "$@"
