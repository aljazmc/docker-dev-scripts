FROM debian:latest

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \ 
    PATH="/usr/src/hashlink:$PATH" \
    USER=heaps

RUN <<'EOT'
runtimeDeps=(
    ca-certificates
    git 
    haxe
    libapache2-mod-neko
    libgc1
    libmariadb3
    libmbedcrypto16
    libmbedtls21
    libmbedx509-7
    libneko2
    libpcre2-8-0
    libsqlite3-0
    neko
    neko-dev
    pipewire
    pipewire-audio-client-libraries 
    pipewire-pulse
    rsync
    sudo
    wireplumber
    zlib1g
)
buildDeps=(
    build-essential
    clang
    libglu1-mesa-dev
    libmbedtls-dev
    libopenal-dev
    libpng-dev
    libsdl3-dev
    libsqlite3-dev
    libturbojpeg0-dev
    libuv1-dev
    libvorbis-dev
    make
    mingw-w64
)
apt-get update
apt-get install --no-install-recommends ${runtimeDeps[@]} ${buildDeps[@]} -y
mkdir -p /usr/src/hashlink /usr/lib/haxe/lib
cd /usr/src/hashlink
git clone https://github.com/HaxeFoundation/hashlink .
git checkout latest
make
make install
EOT

RUN <<EOT
groupadd --gid 1000 $USER
useradd --uid 1000 --gid $USER --shell /bin/bash --create-home $USER
echo "$USER:$USER" | chpasswd
echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$USER
EOT

USER $USER
WORKDIR /home/$USER

CMD ["bash"]
