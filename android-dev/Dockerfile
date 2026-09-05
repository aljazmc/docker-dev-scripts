FROM debian:latest

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive \
    USER=android

ENV ANDROID_HOME="/home/$USER/sdk" \
    ANDROID_SDK_ROOT="/home/$USER/sdk" \
    ANDROID_USER_HOME="/home/$USER/.android" \
    GRADLE_HOME="/home/$USER/sdk/gradle-9.5.1/bin" \
    GRADLE_USER_HOME="/home/$USER/.gradle" \
    LANG=C \
    LC_ALL=C \
    PATH="/home/$USER/app:/home/$USER/sdk/platform-tools:/home/$USER/sdk/build-tools/35.0.0:/home/$USER/sdk/cmdline-tools/latest/bin:/home/$USER/sdk/emulator:/home/$USER/sdk/gradle-9.5.1/bin:/home/$USER/sdk/kotlinc/bin:$PATH"
RUN <<'EOF'
runtimeDeps=(
    ca-certificates
    openbox
    pipewire
    pipewire-audio-client-libraries
    pipewire-pulse
    sudo
    udev
    unzip
    wget
    wireplumber
    xauth
    xinit
    xorg
    xterm
    zip
)
libraries=(
    android-udev-rules
    default-jdk
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
    libx11-xcb1
    mesa-common-dev
    qemu-system-x86
)
apt-get update
apt-get install --no-install-recommends ${runtimeDeps[@]} ${libraries[@]} -y
apt-get dist-clean

groupadd --gid 1000 $USER
useradd --uid 1000 --gid $USER --shell /bin/bash --create-home $USER
echo "$USER:$USER" | chpasswd
echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$USER

/usr/sbin/usermod -aG sudo $USER
/usr/sbin/usermod -aG kvm $USER
EOF

USER $USER
WORKDIR /home/$USER

CMD [ "bash" ]

