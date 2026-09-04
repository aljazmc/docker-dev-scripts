#!/bin/bash

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "This script works only on GNU/Linux systems"
    exit
fi

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
USER=heaps

## Functions

clean() {

docker compose down -v --rmi all --remove-orphans
docker system prune -af --volumes

find . -mindepth 1 -maxdepth 1 \
    | sed "
        /Dockerfile/d;
        /project.sh/d;
    " \
    | xargs -I {} rm -rf {}

}

start() {

    mkdir -p src haxelib

if [[ ! -f compile.hxml ]]; then
    cat <<-EOF > compile.hxml
-cp src
-lib format
-lib heaps
-lib hlsdl
-hl hello.hl
-main Main
EOF
fi

if [[ ! -f docker-compose.yml ]]; then
    cat <<-EOF > docker-compose.yml
services:
    heaps:
        build: .
        working_dir: /home/$USER
        user: $PROJECT_UID:$PROJECT_GID
        environment:
            DISPLAY: $DISPLAY
            XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR
        volumes:
            - .:/home/$USER
            - /tmp/.X11-unix:/tmp/.X11-unix
            - /run/user/${PROJECT_UID}:/run/user/${PROJECT_UID}
            - /var/lib/dbus/machine-id:/var/lib/dbus/machine-id
            - ~/.Xauthority:/home/$USER/.Xauthority
        devices:
            - /dev/dri:/dev/dri
            - /dev/snd:/dev/snd
        network_mode: host
EOF
fi

if [[ ! -f src/Main.hx ]]; then
    cat <<-EOF > src/Main.hx
class Main extends hxd.App {
    override function init() {
        var tf = new h2d.Text(hxd.res.DefaultFont.get(), s2d);
        tf.text = "Hello Hashlink !";
    }
    static function main() {
        new Main();
    }
}
EOF
fi

docker compose run --rm heaps bash -c " \
    haxelib setup haxelib \
    && haxelib --global update haxelib \
    && haxelib fixrepo"

[ ! -d haxelib/format 	]   && docker compose run --rm heaps bash -c "haxelib install format"
[ ! -d haxelib/heaps 	]   && docker compose run --rm heaps bash -c "haxelib install heaps"
[ ! -d haxelib/hlopenal ]   && docker compose run --rm heaps bash -c "haxelib install hlopenal"
[ ! -d haxelib/hlsdl 	]   && docker compose run --rm heaps bash -c "haxelib install hlsdl"
[ ! -d haxelib/hldx 	]   && docker compose run --rm heaps bash -c "haxelib install hldx"

    docker compose run --rm heaps haxe compile.hxml
    docker compose run --rm heaps hl hello.hl
    docker compose run --rm heaps sh -c "printenv"

}

"$1"
