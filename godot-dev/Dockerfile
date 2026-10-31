FROM debian:latest

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive \
    USER=godot

ENV LANG=C \
    LC_ALL=C \
    PATH="$PATH:/opt/blender:/opt/godot:/home/$USER"

RUN <<'EOF'
runtimeDeps=(
    ca-certificates
    ffmpeg
    fluid-soundfont-gm
    fluidsynth
    inkscape
    libpulse0
    nsis
    pipewire-bin
    python3
    python3-cssselect
    python3-lxml
    python3-numpy
    python3-pil
    python3-tinycss2
    sudo
    unzip
    wget
    xorriso
    xz-utils
    zip
)
libraries=(
    libdbus-1-3
    libegl1
    libfontconfig1
    libgl1
    libgl1-mesa-dri
    libglx-mesa0
    libsm6
    libvulkan1
    libx11-6
    libxcursor1
    libxext6
    libxfixes3
    libxi6
    libxinerama1
    libxkbcommon0
    libxrandr2
    libxrender1
    libxxf86vm1
    mesa-vulkan-drivers
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
wget https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_mono_export_templates.tpz
unzip Godot_v4.7.2-stable_mono_export_templates.tpz \
    "templates/version.txt" \
    "templates/linux_*.x86_64" \
    "templates/windows_*_x86_64*.exe" \
    "templates/macos.zip"
rm Godot_v4.7.2-stable_mono_export_templates.tpz
sudo mv templates /opt/godot/templates
wget https://download.blender.org/release/Blender5.2/blender-5.2.3-linux-x64.tar.xz
tar -xJf blender-5.2.3-linux-x64.tar.xz
rm blender-5.2.3-linux-x64.tar.xz
sudo mv blender-5.2.3-linux-x64 /opt/blender
EOF

CMD [ "bash" ]

