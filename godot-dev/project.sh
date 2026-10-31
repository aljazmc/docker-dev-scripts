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

PROJECT_NAME=${PWD##*/} ## PROJECT_NAME = parent directory, also the name of the application
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
RENDER_GID=$(stat -c %g /dev/dri/renderD* 2>/dev/null | head -n 1)
VIDEO_GID=$(stat -c %g /dev/dri/card* 2>/dev/null | head -n 1)
AUDIO_GID=$(stat -c %g /dev/snd/controlC* 2>/dev/null | head -n 1)
GROUP_ADD=$(printf '%s\n' $RENDER_GID $VIDEO_GID $AUDIO_GID | sort -un | sed '/^0\?$/d; s/.*/            - "&"/')
AMD_GPU=$(grep -l 0x1002 /sys/class/drm/renderD*/device/vendor 2>/dev/null | head -n 1)
AMD_PRIME=${AMD_GPU:+pci-$(basename "$(readlink -f "${AMD_GPU%/vendor}")" | tr :. __)}
DRI_DEVICE=$(ls -d /dev/dri 2>/dev/null)
NVIDIA_GPU=$(ls /dev/nvidiactl 2>/dev/null)
NVIDIA_TOOLKIT=$(command -v nvidia-container-runtime-hook)
NVIDIA=${NVIDIA_GPU:+${NVIDIA_TOOLKIT:+yes}}
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
        if [[ -n $NVIDIA_GPU && -z $NVIDIA_TOOLKIT ]]; then
            echo "NVIDIA GPU found, but NVIDIA Container Toolkit is not installed. The container will not use the NVIDIA GPU."
        fi
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
}${NVIDIA:+            NVIDIA_DRIVER_CAPABILITIES: all
            __NV_PRIME_RENDER_OFFLOAD: 1
            __GLX_VENDOR_LIBRARY_NAME: nvidia
            __VK_LAYER_NV_optimus: NVIDIA_only
}        devices:
${DRI_DEVICE:+            - /dev/dri:/dev/dri
}            - /dev/snd:/dev/snd
${GROUP_ADD:+        group_add:
$GROUP_ADD
}${NVIDIA:+        deploy:
            resources:
                reservations:
                    devices:
                        - driver: nvidia
                          count: all
                          capabilities: [gpu]
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

config/name="$PROJECT_NAME"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.7", "C#")

[display]

window/size/viewport_width=960
window/size/viewport_height=540
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[dotnet]

project/assembly_name="$PROJECT_NAME"
EOF
    fi

    if [[ ! -f $PROJECT_NAME.csproj ]]; then
        cat << EOF > $PROJECT_NAME.csproj
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
        AddChild(new Hello());
    }
}
EOF
    fi

    if [[ ! -f Hello.cs ]]; then
        cat << EOF > Hello.cs
using Godot;

/// <summary>A greeting in the middle of the 960x540 viewport, which Godot scales to fit the window.</summary>
public partial class Hello : Label
{
    public override void _Ready()
    {
        Text = "Hello Godot!";
        HorizontalAlignment = HorizontalAlignment.Center;
        VerticalAlignment = VerticalAlignment.Center;
        LabelSettings = new LabelSettings { FontSize = 48 };
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
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
export_path="dist/linux/$PROJECT_NAME/$PROJECT_NAME.x86_64"

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
export_path="dist/windows/$PROJECT_NAME/$PROJECT_NAME.exe"

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
export_path="dist/$PROJECT_NAME-macos.zip"

[preset.2.options]

binary_format/architecture="universal"
application/bundle_identifier="com.example.$PROJECT_NAME"
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

    if ! grep -q "InvariantGlobalization" $PROJECT_NAME.csproj; then
        echo "Enabling invariant globalization in $PROJECT_NAME.csproj, so exports do not depend on system libicu."
        sed -i "0,/<PropertyGroup>/s//&\n    <InvariantGlobalization>true<\/InvariantGlobalization>/" $PROJECT_NAME.csproj
    fi

    if [[ ! -f $PROJECT_NAME.sln ]]; then
        docker compose run --rm godot sh -c " \
            dotnet new sln --format sln --name $PROJECT_NAME \
            && dotnet sln $PROJECT_NAME.sln add $PROJECT_NAME.csproj"
    fi

    mkdir -p dist .local/share/godot/export_templates
    touch dist/.gdignore
    ln -sfn /opt/godot/templates .local/share/godot/export_templates/4.7.2.stable.mono

}

bundleforlinux() {

    exportsetup
    rm -rf dist/linux dist/$PROJECT_NAME-linux-x86_64.tar.gz
    mkdir -p dist/linux/$PROJECT_NAME

    docker compose run --rm godot sh -c "Godot_v4.7.2-stable_mono_linux.x86_64 --headless --export-release Linux dist/linux/$PROJECT_NAME/$PROJECT_NAME.x86_64"

    tar -czf dist/$PROJECT_NAME-linux-x86_64.tar.gz -C dist/linux $PROJECT_NAME

}

bundleforwindows() {

    exportsetup
    rm -rf dist/windows dist/$PROJECT_NAME-windows-x86_64.zip
    mkdir -p dist/windows/$PROJECT_NAME

    docker compose run --rm godot sh -c " \
        Godot_v4.7.2-stable_mono_linux.x86_64 --headless --export-release Windows dist/windows/$PROJECT_NAME/$PROJECT_NAME.exe \
        && cd dist/windows \
        && zip -qr ../$PROJECT_NAME-windows-x86_64.zip $PROJECT_NAME"

}

bundleformac() {

    exportsetup
    rm -f dist/$PROJECT_NAME-macos.zip

    docker compose run --rm godot sh -c "Godot_v4.7.2-stable_mono_linux.x86_64 --headless --export-release macOS dist/$PROJECT_NAME-macos.zip"

}

makebundles() {

    ## Packs the bundles of bundleforlinux, bundleforwindows and bundleformac (whichever exist)
    ## into self-extracting .sh and .exe files, which unpack the bundle to a temporary directory,
    ## run it and remove the directory again, and into a .dmg disk image
    if [[ ! -d dist/linux/$PROJECT_NAME && ! -d dist/windows/$PROJECT_NAME && ! -f dist/$PROJECT_NAME-macos.zip ]]; then
        echo "No bundles found. Run ./project.sh bundleforlinux, bundleforwindows and/or bundleformac first. Exiting..."
        exit 1
    fi

    docker compose run --rm -T -e PROJECT_NAME="$PROJECT_NAME" godot bash -euo pipefail << 'EOF'
if [[ -d dist/linux/$PROJECT_NAME ]]; then
    ## Shell script with the bundle appended as a tar.gz
    cat << HEADER > dist/$PROJECT_NAME-linux-x86_64.sh
#!/bin/sh
set -e
TMP="\$(mktemp -d)"
trap 'rm -rf "\$TMP"' EXIT
trap 'exit 130' INT TERM HUP
ARCHIVE="\$(awk '/^__ARCHIVE__\$/ { print NR + 1; exit }' "\$0")"
tail -n +"\$ARCHIVE" "\$0" | tar -xz -C "\$TMP"
"\$TMP/$PROJECT_NAME.x86_64" "\$@"
exit \$?
__ARCHIVE__
HEADER
    tar -czf - -C dist/linux/$PROJECT_NAME . >> dist/$PROJECT_NAME-linux-x86_64.sh
    chmod +x dist/$PROJECT_NAME-linux-x86_64.sh
    echo "Created dist/$PROJECT_NAME-linux-x86_64.sh"
fi

if [[ -d dist/windows/$PROJECT_NAME ]]; then
    ## Silent NSIS installer doing the same in the user's temporary directory
    cat << NSIS > dist/$PROJECT_NAME.nsi
Unicode true
SetCompressor /SOLID lzma
RequestExecutionLevel user
SilentInstall silent
Name "$PROJECT_NAME"
OutFile "$PROJECT_NAME-windows-x86_64.exe"
!include FileFunc.nsh

Section
    InitPluginsDir
    SetOutPath "\$PLUGINSDIR\\app"
    File /r "windows/$PROJECT_NAME/*"
    \${GetParameters} \$0
    ExecWait '"\$PLUGINSDIR\\app\\$PROJECT_NAME.exe" \$0' \$1
    SetOutPath "\$TEMP"
    StrCpy \$2 0
    retry:
        RMDir /r "\$PLUGINSDIR\\app"
        IfFileExists "\$PLUGINSDIR\\app" 0 done
        IntOp \$2 \$2 + 1
        IntCmp \$2 50 done
        Sleep 100
        Goto retry
    done:
    SetErrorLevel \$1
SectionEnd
NSIS
    makensis -V2 dist/$PROJECT_NAME.nsi
    rm dist/$PROJECT_NAME.nsi
    echo "Created dist/$PROJECT_NAME-windows-x86_64.exe"
fi

if [[ -f dist/$PROJECT_NAME-macos.zip ]]; then
    ## Disk image with the app from the zip of bundleformac and a link to Applications, to drag the app there
    STAGE="$(mktemp -d)"
    chmod 755 "$STAGE"
    unzip -q dist/$PROJECT_NAME-macos.zip -d "$STAGE"
    ln -s /Applications "$STAGE/Applications"
    rm -f dist/$PROJECT_NAME-macos.dmg
    xorriso -as mkisofs -quiet -V "$PROJECT_NAME" -hfsplus -R -o dist/$PROJECT_NAME-macos.dmg "$STAGE"
    rm -rf "$STAGE"
    echo "Created dist/$PROJECT_NAME-macos.dmg"
fi
EOF

}

start() {

    compose
    composehack
    godot

}

"$1"
