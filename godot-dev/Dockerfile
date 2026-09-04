FROM debian:latest

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive \
    USER=godot

ENV LANG=C \
    LC_ALL=C \
    PATH="$PATH:/opt/godot:/home/$USER"

RUN <<'EOF'
runtimeDeps=(
    ca-certificates
    openbox
    pipewire
    pipewire-audio-client-libraries
    pipewire-pulse
    sudo
    unzip
    wget
    wireplumber
    xauth
    xinit
    xorg
    xterm
)
libraries=(
    libegl-dev
    libgl-dev
    libglu1-mesa-dev
    libglx-dev
    libmbedtls-dev
    libopenal-dev
    libpng-dev
    libsdl3-dev
    libsqlite3-dev
    libturbojpeg0-dev
    libuv1-dev
    libvorbis-dev
    libvulkan-dev
    mesa-common-dev
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

RUN <<EOF
wget https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install --no-install-recommends dotnet-sdk-10.0 -y
wget "https://downloads.godotengine.org/?version=4.7.2&flavor=stable&slug=mono_linux_x86_64.zip&platform=linux.64"
unzip "index.html?version=4.7.2&flavor=stable&slug=mono_linux_x86_64.zip&platform=linux.64"
sudo mv Godot_v4.7.2-stable_mono_linux_x86_64 /opt/godot
EOF

CMD [ "bash" ]

