FROM debian:latest

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive \
    USER=bevy

ENV LANG=C \
    LC_ALL=C \
    PATH="$PATH:/home/$USER"

RUN <<'EOF'
runtimeDeps=(
    ca-certificates
    git
    pipewire-alsa
    pipewire-bin
    sudo
)
libraries=(
    g++
    libasound2-dev
    libudev-dev
    libvulkan1
    libwayland-dev
    libx11-6
    libxcursor1
    libxi6
    libxkbcommon-dev
    libxkbcommon-x11-0
    libxrandr2
    mesa-vulkan-drivers
    pkgconf
    rustup
)
apt-get update
apt-get install --no-install-recommends ${runtimeDeps[@]} ${libraries[@]} -y
apt-get dist-clean

groupadd --gid 1000 $USER
useradd --uid 1000 --gid $USER --shell /bin/bash --create-home $USER
echo "$USER:$USER" | chpasswd
echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$USER
EOF

USER $USER
WORKDIR /home/$USER

CMD [ "bash" ]

