#!/bin/bash

## Variables

PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
USER=godot

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
        devices:
            - /dev/dri:/dev/dri
            - /dev/snd:/dev/snd
        network_mode: host
EOF
fi

}

composehack() {

    if  ! grep -q "user\:" "docker-compose.yml"; then
        echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
        sed -i "/working_dir\:/{s@^\( \+\)@\1user\: $PROJECT_UID\:$PROJECT_GID\n\1@}" docker-compose.yml
    fi

}

godot() {

    docker compose run --rm godot sh -c "Godot_v4.7.2-stable_mono_linux.x86_64"
    docker compose run --rm godot sh -c "printenv"

}

start() {

    compose

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        composehack

    fi

    godot

}

"$1"
