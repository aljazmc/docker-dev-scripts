#!/bin/bash

## Check if OS is GNU/Linux

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "Script runs only on GNU/Linux OS. Exiting..."
    exit
fi

## Check if Docker compose plugin is installed

if ! docker compose version > /dev/null 2>&1; then
    echo "Compose plugin is not installed. Exiting..."
    exit
fi

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
RENDER_GID=$(stat -c %g /dev/dri/renderD* 2>/dev/null | head -n 1)
VIDEO_GID=$(stat -c %g /dev/dri/card* 2>/dev/null | head -n 1)
AUDIO_GID=$(stat -c %g /dev/snd/controlC* 2>/dev/null | head -n 1)
GROUP_ADD=$(printf '%s\n' $RENDER_GID $VIDEO_GID $AUDIO_GID | sort -un | sed '/^0\?$/d; s/.*/            - "&"/')
AMD_GPU=$(grep -l 0x1002 /sys/class/drm/renderD*/device/vendor 2>/dev/null | head -n 1)
AMD_PRIME=${AMD_GPU:+pci-$(basename "$(readlink -f "${AMD_GPU%/vendor}")" | tr :. __)}
USER=godot

## Functions

clean() {

    docker compose down -v --rmi all --remove-orphans
    docker system prune -af --volumes

    find . -mindepth 1 -maxdepth 1 \
        | sed "
            /Dockerfile/d;
            /project.sh/d;
            /README.md/d;
        " \
        | xargs -I {} rm -rf {}

}

compose() {

    if [[ ! -f docker-compose.yml ]]; then
        cat << EOF > docker-compose.yml
services:
    godot:
        build: .
        working_dir: /home/$USER
        volumes:
            - .:/home/$USER
            - /tmp/.X11-unix:/tmp/.X11-unix
            - /run/user/$PROJECT_UID:/run/user/$PROJECT_UID
            - /var/lib/dbus/machine-id:/var/lib/dbus/machine-id
            - ~/.Xauthority:/home/$USER/.Xauthority
        environment:
            DISPLAY: $DISPLAY
            XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR
${AMD_PRIME:+            DRI_PRIME: $AMD_PRIME
}        devices:
            - /dev/dri:/dev/dri
            - /dev/snd:/dev/snd
${GROUP_ADD:+        group_add:
$GROUP_ADD
}        network_mode: host
EOF
    fi

}

composehack() {

    if ! grep -q "user\:" "docker-compose.yml"; then
        echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
        sed -i "/working_dir\:/{s@^\( \+\)@\1user\: $PROJECT_UID\:$PROJECT_GID\n\1@}" docker-compose.yml
    fi

}

godot() {

    if [[ ! -f project.godot ]]; then
        cat << EOF > project.godot
config_version=5

[application]

config/name="Hello"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.7", "C#")

[dotnet]

project/assembly_name="Hello"
EOF
    fi

    if [[ ! -f Hello.csproj ]]; then
        cat << EOF > Hello.csproj
<Project Sdk="Godot.NET.Sdk/4.7.2">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <EnableDynamicLoading>true</EnableDynamicLoading>
  </PropertyGroup>
</Project>
EOF
    fi

    if [[ ! -f main.tscn ]]; then
        cat << EOF > main.tscn
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://Main.cs" id="1"]

[node name="Main" type="Node"]
script = ExtResource("1")
EOF
    fi

    if [[ ! -f Main.cs ]]; then
        cat << EOF > Main.cs
using Godot;

public partial class Main : Node
{
    public override void _Ready()
    {
        AddChild(new Label { Text = "Hello Godot!" });
    }
}
EOF
    fi

    docker compose run --rm godot sh -c "Godot_v4.7.2-stable_mono_linux.x86_64 --headless --build-solutions --quit"
    docker compose run --rm godot sh -c "Godot_v4.7.2-stable_mono_linux.x86_64"
    docker compose run --rm godot sh -c "printenv"

}

exportsetup() {

    if [[ ! -f export_presets.cfg ]]; then
        cat << EOF > export_presets.cfg
[preset.0]

name="Linux"
platform="Linux"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="dist/linux/Hello/Hello.x86_64"

[preset.0.options]

binary_format/embed_pck=true
binary_format/architecture="x86_64"

[preset.1]

name="Windows"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="dist/windows/Hello/Hello.exe"

[preset.1.options]

binary_format/embed_pck=true
binary_format/architecture="x86_64"

[preset.2]

name="macOS"
platform="macOS"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="dist/Hello-macos.zip"

[preset.2.options]

binary_format/architecture="universal"
application/bundle_identifier="com.example.hello"
codesign/codesign=1
notarization/notarization=0
EOF
    fi

    if ! grep -q "import_etc2_astc" project.godot; then
        echo "Enabling ETC2/ASTC texture import in project.godot, required by macOS exports."
        if grep -q "^\[rendering\]" project.godot; then
            sed -i "/^\[rendering\]/a\\\ntextures/vram_compression/import_etc2_astc=true" project.godot
        else
            printf "\n[rendering]\n\ntextures/vram_compression/import_etc2_astc=true\n" >> project.godot
        fi
    fi

    if ! grep -q "InvariantGlobalization" Hello.csproj; then
        echo "Enabling invariant globalization in Hello.csproj, so exports do not depend on system libicu."
        sed -i "0,/<PropertyGroup>/s//&\n    <InvariantGlobalization>true<\/InvariantGlobalization>/" Hello.csproj
    fi

    if [[ ! -f Hello.sln ]]; then
        docker compose run --rm godot sh -c " \
            dotnet new sln --format sln --name Hello \
            && dotnet sln Hello.sln add Hello.csproj"
    fi

    mkdir -p dist .local/share/godot/export_templates
    touch dist/.gdignore
    ln -sfn /opt/godot/templates .local/share/godot/export_templates/4.7.2.stable.mono

}

bundleforlinux() {

    exportsetup
    rm -rf dist/linux dist/Hello-linux-x86_64.tar.gz
    mkdir -p dist/linux/Hello

    docker compose run --rm godot sh -c "Godot_v4.7.2-stable_mono_linux.x86_64 --headless --export-release Linux dist/linux/Hello/Hello.x86_64"

    tar -czf dist/Hello-linux-x86_64.tar.gz -C dist/linux Hello

}

bundleforwindows() {

    exportsetup
    rm -rf dist/windows dist/Hello-windows-x86_64.zip
    mkdir -p dist/windows/Hello

    docker compose run --rm godot sh -c " \
        Godot_v4.7.2-stable_mono_linux.x86_64 --headless --export-release Windows dist/windows/Hello/Hello.exe \
        && cd dist/windows \
        && zip -qr ../Hello-windows-x86_64.zip Hello"

}

bundleformac() {

    exportsetup
    rm -f dist/Hello-macos.zip

    docker compose run --rm godot sh -c "Godot_v4.7.2-stable_mono_linux.x86_64 --headless --export-release macOS dist/Hello-macos.zip"

}

start() {

    compose
    composehack
    godot

}

"$1"
