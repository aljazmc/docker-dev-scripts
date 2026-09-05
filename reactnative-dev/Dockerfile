FROM debian:latest

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive \
    NODE_VERSION="26.8.1" \
    USER=android

ENV ANDROID_HOME="/home/$USER/sdk" \
    ANDROID_SDK_ROOT="/home/$USER/sdk" \
    ANDROID_USER_HOME="/home/$USER/.android" \
    GRADLE_HOME="/home/$USER/sdk/gradle-9.0.0/bin" \
    GRADLE_USER_HOME="/home/$USER/.gradle" \
    LANG=C \
    LC_ALL=C \
    PATH="/home/$USER/app:/home/$USER/sdk/platform-tools:/home/$USER/sdk/build-tools/36.0.0:/home/$USER/sdk/cmdline-tools/latest/bin:/home/$USER/sdk/emulator:/home/$USER/sdk/gradle-9.0.0/bin:/home/$USER/sdk/kotlinc/bin:$PATH"
RUN <<'EOF'
runtimeDeps=(
    ca-certificates
    curl
    dirmngr
    git
    gpg
    gpg-agent
    libatomic1
    openbox
    pipewire
    pipewire-audio-client-libraries
    pipewire-pulse
    sudo
    tar
    udev
    unzip
    wget
    wireplumber
    xauth
    xinit
    xorg
    xterm
    xz-utils
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

for key in 5BE8A3F6C8A5C01D106C0AD820B1A390B168D356 DD792F5973C6DE52C432CBDAC77ABFA00DDBF2B7 CC68F5A3106FF448322E48ED27F5E38D5B0A215F 8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4 C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C 108F52B48DB57BB0CC439B2997B01419BD92F80A A363A499291CBBC940DD62E41F10027AF002F8B0; 
do
    { gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" && gpg --batch --fingerprint "$key"; } || \
    { gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" && gpg --batch --fingerprint "$key"; } ;
done

curl -fsSLO --compressed "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz"
curl -fsSLO --compressed "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt.asc"

gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc
gpgconf --kill all
rm -rf ~/.gnupg
grep " node-v${NODE_VERSION}-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c -
tar -xJf "node-v${NODE_VERSION}-linux-x64.tar.xz" -C /usr/local --strip-components=1 --no-same-owner
ln -s /usr/local/bin/node /usr/local/bin/nodejs

rm "node-v${NODE_VERSION}-linux-x64.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt
rm -rf /tmp/*

EOF

USER $USER
WORKDIR /home/$USER

RUN sudo npm install -g corepack

CMD [ "bash" ]

