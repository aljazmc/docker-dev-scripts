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
USER=bevy

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
    bevy:
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

bevy() {

    mkdir -p src

    if [[ ! -f Cargo.toml ]]; then
        cat << EOF > Cargo.toml
[package]
name = "hello"
version = "0.1.0"
edition = "2024"

[dependencies]
bevy = "0.20"

## Optimize dependencies in debug builds, as recommended by bevy
[profile.dev]
opt-level = 1

[profile.dev.package."*"]
opt-level = 3
EOF
    fi

    if [[ ! -f src/main.rs ]]; then
        cat << EOF > src/main.rs
use bevy::prelude::*;

fn main() {
    App::new()
        .add_plugins(DefaultPlugins)
        .add_systems(Startup, setup)
        .run();
}

fn setup(mut commands: Commands) {
    commands.spawn(Camera2d);
    commands.spawn(Text::new("Hello Bevy!"));
}
EOF
    fi

    docker compose run --rm bevy sh -c "rustup default stable && cargo build"
    docker compose run --rm bevy sh -c "cargo run"
    docker compose run --rm bevy sh -c "printenv"

}

bundleforlinux() {

    docker compose run --rm -T bevy bash -euo pipefail << 'EOF'
cargo build --release

rm -rf dist/linux dist/Hello-linux-x86_64.tar.gz
mkdir -p dist/linux/Hello
cp target/release/hello dist/linux/Hello/Hello
strip dist/linux/Hello/Hello
[[ ! -d assets ]] || cp -r assets dist/linux/Hello/

tar -czf dist/Hello-linux-x86_64.tar.gz -C dist/linux Hello
EOF

}

bundleforwindows() {

    docker compose run --rm -T bevy bash -euo pipefail << 'EOF'
rustup target add x86_64-pc-windows-gnu
CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUSTFLAGS="-C target-feature=+crt-static" \
    cargo build --release --target x86_64-pc-windows-gnu

rm -rf dist/windows dist/Hello-windows-x86_64.zip
mkdir -p dist/windows/Hello
cp target/x86_64-pc-windows-gnu/release/hello.exe dist/windows/Hello/Hello.exe
x86_64-w64-mingw32-strip dist/windows/Hello/Hello.exe
[[ ! -d assets ]] || cp -r assets dist/windows/Hello/

## Bundle MinGW runtime DLLs in case anything still links against them
for dll in $(x86_64-w64-mingw32-objdump -p dist/windows/Hello/Hello.exe | sed -n 's/.*DLL Name: //p'); do
    find /usr/lib/gcc/x86_64-w64-mingw32 /usr/x86_64-w64-mingw32/lib -name "$dll" -exec cp {} dist/windows/Hello/ \; -quit
done

cd dist/windows
zip -qr ../Hello-windows-x86_64.zip Hello
EOF

}

start() {

    compose
    composehack
    bevy

}

"$1"
