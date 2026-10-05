#!/usr/bin/env bash
# Launch the clipboard-fixed Remmina image on a Linux/X11 (or XWayland) host.
# Your Remmina config is kept on the HOST (~/.config/remmina + data dir) and
# mounted in, so profiles persist and nothing is baked into the image.
#
# Usage:  ./run-remmina.sh            (uses image IMAGE below)
#         IMAGE=youruser/remmina-fixed:24.04 ./run-remmina.sh
set -euo pipefail
IMAGE="${IMAGE:-remmina-fixed:24.04}"
export DOCKER_HOST="${DOCKER_HOST:-unix:///var/run/docker.sock}"

# allow this container to talk to your X server (revert later with: xhost -local:)
command -v xhost >/dev/null && xhost +local: >/dev/null || true

mkdir -p "$HOME/.config/remmina" "$HOME/.local/share/remmina"

exec docker run --rm -it \
    --name remmina-fixed \
    --user "$(id -u):$(id -g)" \
    -e DISPLAY="${DISPLAY:-:0}" \
    -e HOME=/home/remmina \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v "$HOME/.config/remmina":/home/remmina/.config/remmina \
    -v "$HOME/.local/share/remmina":/home/remmina/.local/share/remmina \
    "$IMAGE" "$@"
