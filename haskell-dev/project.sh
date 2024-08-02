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

## Functions

clean() {

    docker compose down -v --rmi all --remove-orphans
    rm -rf \
        docker-compose.yml \
        helloworld \
        helloworld.hi \
        helloworld.hs \
        helloworld.o

}

start() {

if [[ ! -f docker-compose.yml ]]; then
    cat <<-EOF > docker-compose.yml
services:
    haskell:
        image: haskell:latest
        user: ${PROJECT_UID}:${PROJECT_GID}
        working_dir: /home/$USER
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

if [[ ! -f helloworld.hs ]]; then
    cat <<-EOF > helloworld.hs
main :: IO ()
main = putStrLn "Hello, World!"
EOF
fi

    docker compose run --rm haskell sh -c "printenv"
    docker compose run --rm haskell ghc helloworld.hs
    docker compose run --rm haskell sh -c "./helloworld"

}

"$1"
