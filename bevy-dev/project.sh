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

    mkdir -p assets src

    if [[ ! -f Cargo.toml ]]; then
        cat << EOF > Cargo.toml
[package]
name = "$PROJECT_NAME"
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
mod hello;

use bevy::prelude::*;

fn main() {
    App::new()
        .add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                title: "$PROJECT_NAME".into(),
                resolution: (960, 540).into(),
                ..default()
            }),
            ..default()
        }))
        .insert_resource(ClearColor(Color::srgb(0.1, 0.1, 0.15)))
        .add_plugins(hello::HelloPlugin)
        .run();
}
EOF
    fi

    if [[ ! -f src/hello.rs ]]; then
        cat << EOF > src/hello.rs
use bevy::camera::ScalingMode;
use bevy::prelude::*;

/// Size of the visible area in world units, scaled by the camera to fit the window.
const VIEW_WIDTH: f32 = 960.;
const VIEW_HEIGHT: f32 = 540.;

pub struct HelloPlugin;

impl Plugin for HelloPlugin {
    fn build(&self, app: &mut App) {
        app.add_systems(Startup, setup);
    }
}

fn setup(mut commands: Commands) {
    commands.spawn((
        Camera2d,
        Projection::Orthographic(OrthographicProjection {
            scaling_mode: ScalingMode::AutoMin { min_width: VIEW_WIDTH, min_height: VIEW_HEIGHT },
            ..OrthographicProjection::default_2d()
        }),
    ));
    commands.spawn((Text2d::new("Hello Bevy!"), TextFont::from_font_size(48.)));
}
EOF
    fi

    docker compose run --rm bevy sh -c "rustup default stable && cargo build"
    docker compose run --rm bevy sh -c "cargo run"
    docker compose run --rm bevy sh -c "printenv"

}

bundleforlinux() {

    docker compose run --rm -T -e PROJECT_NAME="$PROJECT_NAME" bevy bash -euo pipefail << 'EOF'
cargo build --release

rm -rf dist/linux dist/$PROJECT_NAME-linux-x86_64.tar.gz
mkdir -p dist/linux/$PROJECT_NAME
cp target/release/$PROJECT_NAME dist/linux/$PROJECT_NAME/$PROJECT_NAME
strip dist/linux/$PROJECT_NAME/$PROJECT_NAME
[[ ! -d assets ]] || cp -r assets dist/linux/$PROJECT_NAME/

tar -czf dist/$PROJECT_NAME-linux-x86_64.tar.gz -C dist/linux $PROJECT_NAME
EOF

}

bundleforwindows() {

    docker compose run --rm -T -e PROJECT_NAME="$PROJECT_NAME" bevy bash -euo pipefail << 'EOF'
rustup target add x86_64-pc-windows-gnu
CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUSTFLAGS="-C target-feature=+crt-static" \
    cargo build --release --target x86_64-pc-windows-gnu

rm -rf dist/windows dist/$PROJECT_NAME-windows-x86_64.zip
mkdir -p dist/windows/$PROJECT_NAME
cp target/x86_64-pc-windows-gnu/release/$PROJECT_NAME.exe dist/windows/$PROJECT_NAME/$PROJECT_NAME.exe
x86_64-w64-mingw32-strip dist/windows/$PROJECT_NAME/$PROJECT_NAME.exe
[[ ! -d assets ]] || cp -r assets dist/windows/$PROJECT_NAME/

## Bundle MinGW runtime DLLs in case anything still links against them
for dll in $(x86_64-w64-mingw32-objdump -p dist/windows/$PROJECT_NAME/$PROJECT_NAME.exe | sed -n 's/.*DLL Name: //p'); do
    find /usr/lib/gcc/x86_64-w64-mingw32 /usr/x86_64-w64-mingw32/lib -name "$dll" -exec cp {} dist/windows/$PROJECT_NAME/ \; -quit
done

cd dist/windows
zip -qr ../$PROJECT_NAME-windows-x86_64.zip $PROJECT_NAME
EOF

}

makebundles() {

    ## Packs the bundles of bundleforlinux and bundleforwindows into self-extracting files,
    ## which unpack the bundle to a temporary directory, run it and remove the directory again
    if [[ ! -d dist/linux/$PROJECT_NAME && ! -d dist/windows/$PROJECT_NAME ]]; then
        echo "No bundles found. Run ./project.sh bundleforlinux and/or ./project.sh bundleforwindows first. Exiting..."
        exit 1
    fi

    docker compose run --rm -T -e PROJECT_NAME="$PROJECT_NAME" bevy bash -euo pipefail << 'EOF'
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
"\$TMP/$PROJECT_NAME" "\$@"
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
EOF

}

start() {

    compose
    composehack
    bevy

}

"$1"
