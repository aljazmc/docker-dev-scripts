FROM debian:latest

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive \
    USER=heaps

ENV LANG=C \
    LC_ALL=C \
    PATH="$PATH:/home/$USER"

RUN <<'EOF'
runtimeDeps=(
    ca-certificates
    git
    haxe
    libpulse0
    neko
    pipewire-bin
    rsync
    sudo
)
libraries=(
    libgl1
    libgl1-mesa-dri
    libmbedcrypto16
    libmbedtls21
    libmbedx509-7
    libopenal1
    libpng16-16t64
    libsdl3-0
    libsqlite3-0
    libturbojpeg0
    libuv1t64
    libvorbisfile3
    zlib1g
)
buildDeps=(
    g++
    libgl-dev
    libmbedtls-dev
    libopenal-dev
    libpng-dev
    libsdl3-dev
    libsqlite3-dev
    libturbojpeg0-dev
    libuv1-dev
    libvorbis-dev
    make
)
apt-get update
apt-get install --no-install-recommends ${runtimeDeps[@]} ${libraries[@]} ${buildDeps[@]} -y

git clone --depth 1 --branch latest https://github.com/HaxeFoundation/hashlink /usr/src/hashlink
make -C /usr/src/hashlink
make -C /usr/src/hashlink install
ldconfig
rm -rf /usr/src/hashlink

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
