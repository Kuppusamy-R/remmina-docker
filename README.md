# remmina-fixed

Remmina with a **clipboard-fixed FreeRDP** for Ubuntu 24.04.

## Why
Ubuntu 24.04 ships FreeRDP **3.32.0**, which has a regression ([FreeRDP #13486](https://github.com/FreeRDP/FreeRDP/issues/13486)):
copying **~750+ characters** over RDP (a clipboard PDU spanning more than one 1600-byte
channel chunk) fails with `cliprdr read error` / error **1359** and the whole session
disconnects and reconnects. Upstream fixed it in **3.32.1** (PR #13487).

This image = **stock Remmina (full UI)** + **FreeRDP 3.32.0 patched with the one-line fix**,
built from source. No app changes; only the shared library is patched.

## Run (Linux + X11 / XWayland)
```bash
./run-remmina.sh
# or, after pulling from a registry:
IMAGE=<youruser>/remmina-fixed:24.04 ./run-remmina.sh
```
Your connection profiles live on the host (`~/.config/remmina`) and are mounted in — the
image itself ships **no profiles and no credentials**.

Requirements: a Linux host with an X server (native X11, or XWayland on Wayland). macOS/
Windows need an X server (e.g. VcXsrv/XQuartz) and are not covered here.

## Build
```bash
docker build -t remmina-fixed:24.04 .
```

## Publish (maintainer)
```bash
docker tag remmina-fixed:24.04 <youruser>/remmina-fixed:24.04
docker push <youruser>/remmina-fixed:24.04
```
The image is all FOSS (Ubuntu + Remmina + FreeRDP + a one-line FreeRDP fix) and safe to
publish publicly **as long as it contains no connection profiles or credentials** — this
Dockerfile bakes none; keep it that way.

## Retire
Once Ubuntu ships FreeRDP ≥ 3.32.1, this image is no longer needed — use stock Remmina.
