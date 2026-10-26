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
USER=heaps

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
    heaps:
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
        devices:
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

haxelib() {

    mkdir -p haxelib

    docker compose run --rm heaps bash -c " \
        haxelib setup haxelib \
        && haxelib --global update haxelib \
        && haxelib fixrepo"

    for lib in format heaps hlopenal hlsdl hldx; do
        if [[ ! -d haxelib/$lib ]]; then
            docker compose run --rm heaps bash -c "haxelib install $lib"
        fi
    done

}

heaps() {

    mkdir -p src

    if [[ ! -f compile.hxml ]]; then
        cat << EOF > compile.hxml
-cp src
-lib format
-lib heaps
-lib hlsdl
-hl hello.hl
-main Main
EOF
    fi

    if [[ ! -f src/Main.hx ]]; then
        cat << EOF > src/Main.hx
class Main extends hxd.App {
    override function init() {
        var tf = new h2d.Text(hxd.res.DefaultFont.get(), s2d);
        tf.text = "Hello Hashlink!";
    }
    static function main() {
        new Main();
    }
}
EOF
    fi

    docker compose run --rm heaps haxe compile.hxml
    docker compose run --rm heaps hl hello.hl
    docker compose run --rm heaps sh -c "printenv"

}

bundleforlinux() {

    docker compose run --rm heaps haxe compile.hxml

    docker compose run --rm -T heaps bash -euo pipefail << 'EOF'
rm -rf dist/linux dist/Hello-linux-x86_64.tar.gz
mkdir -p dist/linux/Hello
cp /usr/local/bin/hl /usr/local/lib/libhl.so /usr/local/lib/*.hdll dist/linux/Hello/
cp hello.hl dist/linux/Hello/hlboot.dat
[[ ! -d res ]] || cp -r res dist/linux/Hello/

## Bundle shared libraries, skipping (with their dependencies) the ones every desktop provides
queue=(dist/linux/Hello/hl dist/linux/Hello/*.hdll)
while (( ${#queue[@]} )); do
    for lib in $(objdump -p "${queue[0]}" | awk '/NEEDED/ {print $2}'); do
        [[ ! -e dist/linux/Hello/$lib ]] || continue
        [[ ! $lib =~ ^(ld-linux|libc\.|libm\.|libdl\.|libpthread\.|librt\.|libstdc\+\+|libgcc_s|libGL|libEGL|libOpenGL|libX|libxcb|libxkbcommon|libdrm|libgbm|libvulkan|libasound|libpulse|libpipewire|libdbus|libudev|libsystemd) ]] || continue
        cp -L "$(ldconfig -p | awk -v lib="$lib" '$1 == lib && /x86-64/ {print $NF; exit}')" dist/linux/Hello/
        queue+=("dist/linux/Hello/$lib")
    done
    queue=("${queue[@]:1}")
done

cat << 'LAUNCHER' > dist/linux/Hello/Hello
#!/bin/sh
cd "$(dirname "$(readlink -f "$0")")" || exit 1
LD_LIBRARY_PATH=".${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" exec ./hl hlboot.dat "$@"
LAUNCHER
chmod +x dist/linux/Hello/Hello

tar -czf dist/Hello-linux-x86_64.tar.gz -C dist/linux Hello
EOF

}

bundleforwindows() {

    docker compose run --rm heaps haxe compile.hxml

    docker compose run --rm -T heaps bash -euo pipefail << 'EOF'
rm -rf dist/windows dist/Hello-windows-x86_64.zip
mkdir -p dist/windows/Hello
cp -r /opt/hashlink/windows/. dist/windows/Hello/
mv dist/windows/Hello/hl.exe dist/windows/Hello/Hello.exe
cp hello.hl dist/windows/Hello/hlboot.dat
[[ ! -d res ]] || cp -r res dist/windows/Hello/

cd dist/windows
zip -qr ../Hello-windows-x86_64.zip Hello
EOF

}

bundleformac() {

    docker compose run --rm heaps haxe compile.hxml

    docker compose run --rm -T heaps bash -euo pipefail << 'EOF'
rm -rf dist/macos dist/Hello-macos.zip
mkdir -p dist/macos/Hello.app/Contents/MacOS
cp -L /opt/hashlink/macos/{hl,libhl.2.dylib,libopenal.1.dylib,*.hdll} dist/macos/Hello.app/Contents/MacOS/
cp hello.hl dist/macos/Hello.app/Contents/MacOS/hlboot.dat
[[ ! -d res ]] || cp -r res dist/macos/Hello.app/Contents/MacOS/

cat << 'LAUNCHER' > dist/macos/Hello.app/Contents/MacOS/Hello
#!/bin/sh
cd "$(dirname "$0")" || exit 1
exec ./hl hlboot.dat "$@"
LAUNCHER
chmod +x dist/macos/Hello.app/Contents/MacOS/Hello

cat << 'PLIST' > dist/macos/Hello.app/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Hello</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.hello</string>
    <key>CFBundleName</key>
    <string>Hello</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

cd dist/macos
zip -qry ../Hello-macos.zip Hello.app
EOF

}

start() {

    compose
    composehack
    haxelib
    heaps

}

"$1"
