FROM debian:latest

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive \
    USER=bevy

ENV LANG=C \
    LC_ALL=C \
    PATH="$PATH:/opt/blender:/home/$USER"

RUN <<'EOF'
runtimeDeps=(
    ca-certificates
    ffmpeg
    fluid-soundfont-gm
    fluidsynth
    git
    inkscape
    nsis
    pipewire-alsa
    pipewire-bin
    python3
    python3-cssselect
    python3-lxml
    python3-numpy
    python3-pil
    python3-tinycss2
    sudo
    zip
)
libraries=(
    g++
    gcc-mingw-w64-x86-64
    libasound2-dev
    libegl1
    libgl1
    libgl1-mesa-dri
    libsm6
    libudev-dev
    libvulkan1
    libwayland-dev
    libx11-6
    libxcursor1
    libxfixes3
    libxi6
    libxkbcommon-dev
    libxkbcommon-x11-0
    libxkbcommon0
    libxrandr2
    libxrender1
    libxxf86vm1
    mesa-vulkan-drivers
    pkgconf
    rustup
)
buildDeps=(
    curl
    xz-utils
)
apt-get update
apt-get install --no-install-recommends ${runtimeDeps[@]} ${libraries[@]} ${buildDeps[@]} -y

curl -fsSL https://download.blender.org/release/Blender5.2/blender-5.2.3-linux-x64.tar.xz | tar -xJ -C /opt
mv /opt/blender-5.2.3-linux-x64 /opt/blender

apt-get purge --auto-remove ${buildDeps[@]} -y
apt-get dist-clean

groupadd --gid 1000 $USER
useradd --uid 1000 --gid $USER --shell /bin/bash --create-home $USER
echo "$USER:$USER" | chpasswd
echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$USER
EOF

USER $USER
WORKDIR /home/$USER

CMD [ "bash" ]

