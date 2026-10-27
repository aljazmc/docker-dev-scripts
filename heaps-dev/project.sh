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

    mkdir -p res src

    if [[ ! -f compile.hxml ]]; then
        cat << EOF > compile.hxml
-cp src
-lib format
-lib heaps
-lib hlsdl
-hl $PROJECT_NAME.hl
-main Main
EOF
    fi

    if [[ ! -f src/Main.hx ]]; then
        cat << EOF > src/Main.hx
class Main extends hxd.App {

    public static inline var WIDTH = 960;
    public static inline var HEIGHT = 540;

    override function init() {
        // files in res/, embedded into $PROJECT_NAME.hl at compile time
        hxd.Res.initEmbed();
        var window = hxd.Window.getInstance();
        window.title = "$PROJECT_NAME";
        window.resize(WIDTH, HEIGHT);
        // the scene always shows a WIDTH x HEIGHT area, scaled to fit the window
        s2d.scaleMode = LetterBox(WIDTH, HEIGHT);
        engine.backgroundColor = 0x1a1a26;
        new Hello(s2d);
    }

    static function main() {
        new Main();
    }

}
EOF
    fi

    if [[ ! -f src/Hello.hx ]]; then
        cat << EOF > src/Hello.hx
/** A greeting in the middle of the scene. **/
class Hello extends h2d.Object {

    static inline var SCALE = 4;

    public function new( ?parent : h2d.Object ) {
        super(parent);
        var text = new h2d.Text(hxd.res.DefaultFont.get(), this);
        text.text = "Hello Hashlink!";
        text.textAlign = Center;
        text.maxWidth = Main.WIDTH / SCALE;
        text.setScale(SCALE);
        text.y = (Main.HEIGHT - text.textHeight * SCALE) / 2;
    }

}
EOF
    fi

    docker compose run --rm heaps haxe compile.hxml
    docker compose run --rm heaps hl $PROJECT_NAME.hl
    docker compose run --rm heaps sh -c "printenv"

}

bundleforlinux() {

    docker compose run --rm heaps haxe compile.hxml

    docker compose run --rm -T -e PROJECT_NAME="$PROJECT_NAME" heaps bash -euo pipefail << 'EOF'
rm -rf dist/linux dist/$PROJECT_NAME-linux-x86_64.tar.gz
mkdir -p dist/linux/$PROJECT_NAME
cp /usr/local/bin/hl /usr/local/lib/libhl.so /usr/local/lib/*.hdll dist/linux/$PROJECT_NAME/
cp "$PROJECT_NAME.hl" dist/linux/$PROJECT_NAME/hlboot.dat
[[ ! -d res ]] || cp -r res dist/linux/$PROJECT_NAME/

## Bundle shared libraries, skipping (with their dependencies) the ones every desktop provides
queue=(dist/linux/$PROJECT_NAME/hl dist/linux/$PROJECT_NAME/*.hdll)
while (( ${#queue[@]} )); do
    for lib in $(objdump -p "${queue[0]}" | awk '/NEEDED/ {print $2}'); do
        [[ ! -e dist/linux/$PROJECT_NAME/$lib ]] || continue
        [[ ! $lib =~ ^(ld-linux|libc\.|libm\.|libdl\.|libpthread\.|librt\.|libstdc\+\+|libgcc_s|libGL|libEGL|libOpenGL|libX|libxcb|libxkbcommon|libdrm|libgbm|libvulkan|libasound|libpulse|libpipewire|libdbus|libudev|libsystemd) ]] || continue
        cp -L "$(ldconfig -p | awk -v lib="$lib" '$1 == lib && /x86-64/ {print $NF; exit}')" dist/linux/$PROJECT_NAME/
        queue+=("dist/linux/$PROJECT_NAME/$lib")
    done
    queue=("${queue[@]:1}")
done

cat << 'LAUNCHER' > dist/linux/$PROJECT_NAME/$PROJECT_NAME
#!/bin/sh
cd "$(dirname "$(readlink -f "$0")")" || exit 1
LD_LIBRARY_PATH=".${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" exec ./hl hlboot.dat "$@"
LAUNCHER
chmod +x dist/linux/$PROJECT_NAME/$PROJECT_NAME

tar -czf dist/$PROJECT_NAME-linux-x86_64.tar.gz -C dist/linux $PROJECT_NAME
EOF

}

bundleforwindows() {

    docker compose run --rm heaps haxe compile.hxml

    docker compose run --rm -T -e PROJECT_NAME="$PROJECT_NAME" heaps bash -euo pipefail << 'EOF'
rm -rf dist/windows dist/$PROJECT_NAME-windows-x86_64.zip
mkdir -p dist/windows/$PROJECT_NAME
cp -r /opt/hashlink/windows/. dist/windows/$PROJECT_NAME/
mv dist/windows/$PROJECT_NAME/hl.exe dist/windows/$PROJECT_NAME/$PROJECT_NAME.exe
cp "$PROJECT_NAME.hl" dist/windows/$PROJECT_NAME/hlboot.dat
[[ ! -d res ]] || cp -r res dist/windows/$PROJECT_NAME/

cd dist/windows
zip -qr ../$PROJECT_NAME-windows-x86_64.zip $PROJECT_NAME
EOF

}

bundleformac() {

    docker compose run --rm heaps haxe compile.hxml

    docker compose run --rm -T -e PROJECT_NAME="$PROJECT_NAME" heaps bash -euo pipefail << 'EOF'
rm -rf dist/macos dist/$PROJECT_NAME-macos.zip
mkdir -p dist/macos/$PROJECT_NAME.app/Contents/MacOS
cp -L /opt/hashlink/macos/{hl,libhl.2.dylib,libopenal.1.dylib,*.hdll} dist/macos/$PROJECT_NAME.app/Contents/MacOS/
cp "$PROJECT_NAME.hl" dist/macos/$PROJECT_NAME.app/Contents/MacOS/hlboot.dat
[[ ! -d res ]] || cp -r res dist/macos/$PROJECT_NAME.app/Contents/MacOS/

cat << 'LAUNCHER' > dist/macos/$PROJECT_NAME.app/Contents/MacOS/$PROJECT_NAME
#!/bin/sh
cd "$(dirname "$0")" || exit 1
exec ./hl hlboot.dat "$@"
LAUNCHER
chmod +x dist/macos/$PROJECT_NAME.app/Contents/MacOS/$PROJECT_NAME

cat << PLIST > dist/macos/$PROJECT_NAME.app/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$PROJECT_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.$PROJECT_NAME</string>
    <key>CFBundleName</key>
    <string>$PROJECT_NAME</string>
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
zip -qry ../$PROJECT_NAME-macos.zip $PROJECT_NAME.app
EOF

}

makebundles() {

    ## Packs the bundles of bundleforlinux, bundleforwindows and bundleformac (whichever exist)
    ## into self-extracting .sh and .exe files, which unpack the bundle to a temporary directory,
    ## run it and remove the directory again, and into a .dmg disk image
    if [[ ! -d dist/linux/$PROJECT_NAME && ! -d dist/windows/$PROJECT_NAME && ! -d dist/macos/$PROJECT_NAME.app ]]; then
        echo "No bundles found. Run ./project.sh bundleforlinux, bundleforwindows and/or bundleformac first. Exiting..."
        exit 1
    fi

    docker compose run --rm -T -e PROJECT_NAME="$PROJECT_NAME" heaps bash -euo pipefail << 'EOF'
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

if [[ -d dist/macos/$PROJECT_NAME.app ]]; then
    ## Disk image with $PROJECT_NAME.app and a link to Applications, to drag the app there
    STAGE="$(mktemp -d)"
    chmod 755 "$STAGE"
    cp -a dist/macos/$PROJECT_NAME.app "$STAGE"/
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
    haxelib
    heaps

}

"$1"
