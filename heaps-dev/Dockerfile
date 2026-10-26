FROM debian:latest

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive \
    USER=heaps

ENV LANG=C \
    LC_ALL=C \
    PATH="$PATH:/home/$USER"

RUN <<'EOF'
runtimeDeps=(
    binutils
    ca-certificates
    git
    haxe
    libpulse0
    neko
    pipewire-bin
    rsync
    sudo
    zip
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
    curl
    g++
    gcc-mingw-w64-x86-64-posix-runtime
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
    mingw-w64-x86-64-dev
    unzip
)
apt-get update
apt-get install --no-install-recommends ${runtimeDeps[@]} ${libraries[@]} ${buildDeps[@]} -y

git clone --depth 1 --branch latest https://github.com/HaxeFoundation/hashlink /usr/src/hashlink
make -C /usr/src/hashlink
make -C /usr/src/hashlink install
ldconfig

hlRelease=hashlink-$(git -C /usr/src/hashlink rev-parse --short=7 HEAD)
hlUrl=https://github.com/HaxeFoundation/hashlink/releases/download/latest
mkdir -p /opt/hashlink/windows

## Windows runtime built with MinGW, so bundles do not depend on the Visual C++ Redistributable
curl -fsSL -o /tmp/$hlRelease-win64-cmake-mingw.zip $hlUrl/$hlRelease-win64-cmake-mingw.zip
unzip -q /tmp/$hlRelease-win64-cmake-mingw.zip -d /tmp
mv /tmp/$hlRelease-win64-cmake-mingw/bin/*.{exe,dll} /tmp/$hlRelease-win64-cmake-mingw/lib/*.hdll /opt/hashlink/windows/
rm /opt/hashlink/windows/video.hdll
curl -fsSL -o /tmp/$hlRelease-win64.zip $hlUrl/$hlRelease-win64.zip
unzip -qj /tmp/$hlRelease-win64.zip $hlRelease-win64/SDL3.dll -d /opt/hashlink/windows
cp /usr/lib/gcc/x86_64-w64-mingw32/*-posix/{libgcc_s_seh-1,libstdc++-6}.dll /usr/x86_64-w64-mingw32/lib/libwinpthread-1.dll /opt/hashlink/windows/
strip --strip-debug /opt/hashlink/windows/{libgcc_s_seh-1,libstdc++-6,libwinpthread-1}.dll
rm -rf /tmp/$hlRelease-win64-cmake-mingw /tmp/$hlRelease-win64-cmake-mingw.zip /tmp/$hlRelease-win64.zip

curl -fsSL $hlUrl/$hlRelease-darwin-cmake.tar.gz | tar -xz -C /opt/hashlink
mv /opt/hashlink/$hlRelease-darwin-cmake /opt/hashlink/macos
rm -rf /opt/hashlink/macos/include
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
