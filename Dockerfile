# Remmina with a clipboard-fixed FreeRDP (Ubuntu 24.04).
#
# Ubuntu 24.04 ships FreeRDP 3.32.0, which drops the RDP session with
# "cliprdr read error / 1359" whenever a clipboard transfer spans more than one
# 1600-byte channel chunk (~750+ chars). Upstream fixed this in 3.32.1
# (FreeRDP issue #13486). This image keeps the stock Remmina UI and only
# swaps in a patched FreeRDP built from the 3.32.0 tag + the one-line fix.
#
# It ships NO connection profiles or credentials. Mount your own config at run
# time (see run-remmina.sh).

# ---- stage 1: build patched FreeRDP 3.32.0 libraries ----
FROM ubuntu:24.04 AS freerdp
ENV DEBIAN_FRONTEND=noninteractive
# Pull FreeRDP's exact Ubuntu build-dependencies (enable deb-src, then build-dep)
# so every required library is present and channel parity matches the stock
# freerdp3 package. Add the few tools we drive the build with.
RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends git cmake ninja-build g++ pkg-config ca-certificates \
    && apt-get build-dep -y freerdp3 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone --depth 1 --branch 3.32.0 https://github.com/FreeRDP/FreeRDP.git .
COPY freerdp-clipfix.patch /tmp/freerdp-clipfix.patch
RUN git apply --verbose /tmp/freerdp-clipfix.patch
RUN cmake -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/freerdp \
        -DWITH_SERVER=OFF -DWITH_SHADOW=OFF -DWITH_SAMPLE=OFF \
        -DBUILD_TESTING=OFF -DWITH_CLIENT=OFF -DWITH_CLIENT_SDL=OFF \
        -DWITH_X11=OFF -DWITH_SWSCALE=OFF -DWITH_FFMPEG=OFF \
        -DWITH_KRB5=OFF -DWITH_PKCS11=OFF \
    && ninja -C build && ninja -C build install

# ---- stage 2: runtime (stock Remmina + good UI deps + patched FreeRDP) ----
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
LABEL org.opencontainers.image.description="Remmina with clipboard-fixed FreeRDP (FreeRDP #13486 / error 1359 fix, Ubuntu 24.04)."
RUN apt-get update && apt-get install -y --no-install-recommends \
        remmina remmina-plugin-rdp \
        adwaita-icon-theme hicolor-icon-theme librsvg2-common \
        dbus-x11 at-spi2-core gsettings-desktop-schemas \
        fonts-dejavu-core fontconfig ca-certificates \
        liburiparser1 \
    && rm -rf /var/lib/apt/lists/*

# overlay the patched FreeRDP shared libraries on top of the stock ones
COPY --from=freerdp /opt/freerdp/lib/libfreerdp3.so.3.32.0        /usr/lib/x86_64-linux-gnu/
COPY --from=freerdp /opt/freerdp/lib/libfreerdp-client3.so.3.32.0 /usr/lib/x86_64-linux-gnu/
COPY --from=freerdp /opt/freerdp/lib/libwinpr3.so.3.32.0          /usr/lib/x86_64-linux-gnu/
RUN ldconfig

# The run script sets the identity with --user $(id -u):$(id -g) at runtime, so
# HOME just needs to be writable by any uid. No baked user (ubuntu:24.04 already
# uses uid 1000).
RUN mkdir -p /home/remmina && chmod 0777 /home/remmina
ENV HOME=/home/remmina
ENTRYPOINT ["remmina"]
