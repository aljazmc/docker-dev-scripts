#!/bin/bash

## Checks if OS is linux and docker compose is installed

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "Script runs only on GNU/Linux OS. Exiting..."
    exit
fi

if [[ ! -x "$(command -v compose version)" ]]; then
    echo "Compose plugin is not installed. Exiting..."
    exit
fi

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)

export COMPOSE_IGNORE_ORPHANS=True
echo "Setting COMPOSE_IGNORE_ORPHANS to true and making it accessible to current shell process"

## Functions

clean() {

    docker compose down -v --rmi all --remove-orphans
    rm -rf \
        docker-compose.yml \
        Dockerfile \
        hello.ml \
        helloworld \
        .opam

}

start() {

if [ ! -f docker-compose.yml ]; then
    cat <<-EOF > docker-compose.yml
services:
    ocamlopam:
        image: ocaml/opam:debian
        user: ${PROJECT_UID}:${PROJECT_GID}
        working_dir: /home/$USER
        command: /bin/sh -c "opam init --root=/home/$USER/.opam"
        environment:
            DISPLAY: $DISPLAY
            XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR
        volumes:
            - .:/home/$USER
            - /tmp/.X11-unix:/tmp/.X11-unix
            - /run/user/${PROJECT_UID}:/run/user/${PROJECT_UID}
            - ~/.Xauthority:/root/.Xauthority
        devices:
            - /dev/dri:/dev/dri
            - /dev/snd:/dev/snd
        network_mode: host
EOF
fi

if [ ! -d .opam ]; then

    docker compose run ocamlopam

    if grep "OPAMROOT" docker-compose.yml
    then
        echo "\$OPAMROOT is already present in docker-compose.yml"
    else
        echo "adding \$OPAMROOT to docker-compose.yml"
        sed -i "9i \ \ \ \ \ \ \ \ \ \ \ \ OPAMROOT: /home/$USER/.opam" docker-compose.yml
    fi

    docker compose run ocamlopam opam config list
    docker compose run ocamlopam opam install core
    docker compose run ocamlopam dune init proj helloworld

fi

    docker compose run ocamlopam sh -c "cd helloworld && dune build"
    docker compose run ocamlopam sh -c "cd helloworld && dune exec helloworld"
    docker compose run ocamlopam sh -c "printenv"

}

$1
